# frozen_string_literal: true

module FatTerm
  class Terminal
    # Commands are plain Ruby arrays for now.
    #
    # Suggested shapes:
    #
    # Terminal/runtime commands:
    #   [:terminal, :quit]
    #   [:terminal, :push, session]
    #   [:terminal, :pop]
    #
    # Session-targeted commands (no special casing):
    #   [:send, :alert, :show, { level: :warning, message: "No matches" }]
    #   [:send, :alert, :clear, {}]
    #
    # You can add more later; Terminal only needs a small dispatcher.

    attr_reader :screen, :renderer, :event_source

    def initialize(prompt: "> ", on_accept: nil, completion_proc: nil, history_ctx: nil, env: nil)
      @prompt = Prompt.ensure(prompt)
      @on_accept = on_accept
      @completion_proc = completion_proc
      @history_ctx = history_ctx
      @env = env

      @running = false
      @stack = []
      @pinned = []
      @sessions = []
      @sessions_by_id = {}
      @modal_stack = []
    end

    # --- Session management ------------------------------------------------

    def push(session)
      FatTerm.debug("Terminal#push(#{session})", tag: :session)
      @stack << session
      register(session)
      commands = session.init(terminal: self)
      apply_commands(commands)
      session
    end

    def pop
      FatTerm.debug("Terminal#pop -> #{@stack.last}", tag: :session)
      @stack.pop
    end

    def pin(session)
      FatTerm.debug("Terminal#pin(#{session})", tag: :session)
      @pinned << session
      register(session)
      commands = session.init(terminal: self)
      apply_commands(commands)
      session
    end

    def active_session
      top = @modal_stack.last
      return top[:session] if top

      focused_session
    end

    def focused_session
      top = @stack.last
      return top[:session] if top.is_a?(Hash)

      top
    end

    def register(session)
      return unless session.respond_to?(:id)
      return if session.id.nil?

      @sessions_by_id[session.id] = session
    end

    def find_session(id)
      @sessions_by_id[id]
    end

    def push_modal(session, owner:)
      @modal_stack << { session: session, owner: owner }
      msg = "Terminal#push_modal: size=#{@modal_stack.length} session=#{session.class} object_id=#{session.object_id}"
      FatTerm.debug(msg, tag: :session)
      register(session)
      @renderer.invalidate! if defined?(@renderer) && @renderer
      commands = session.init(terminal: self)
      apply_commands(commands)
    end

    def pop_modal
      top = @modal_stack.pop
      msg = "Terminal#pop_modal: size=#{@modal_stack.length} popped=#{top && top[:session].class}"
      FatTerm.debug(msg, tag: :session)
      session = top && top[:session]

      session.close if session&.respond_to?(:close)
      @renderer.invalidate! if @renderer
      nil
    end

    # Return the owner of the top modal session without modifying the stack.
    def modal_owner
      top = @modal_stack.last
      top && top[:owner]
    end

    # --- Runtime -----------------------------------------------------------

    def go
      preflight!
      start_curses!
      install_default_sessions!

      @running = true
      render_frame

      while @running
        dirty = false
        msg = event_source.next_event
        if msg
          dispatch_message(msg)
          dirty = true
        end
        s = active_session
        begin
          tick_dirty = !!s&.tick(terminal: self)
          dirty ||= tick_dirty
        rescue StandardError => e
          FatTerm.error("Terminal#go tick failed: #{e.class}: #{e.message}", tag: :terminal)
          dirty = true
        end
        render_frame if dirty
      end
    rescue => e
      FatTerm.error("Terminal#go fatal error: #{e.class}: #{e.message}", tag: :terminal)
      FatTerm.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      raise
    ensure
      begin
        stop_curses!
      rescue => e
        FatTerm.error("Terminal#go stop_curses! failed: #{e.class}: #{e.message}", tag: :terminal)
        FatTerm.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      end

      begin
        persist_sessions!
      rescue => e
        FatTerm.error("Terminal#go persist_sessions! failed: #{e.class}: #{e.message}", tag: :terminal)
        FatTerm.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      end
    end

    private

    def preflight!
      FatTerm::Config.config
      FatTerm::Config.keydefs
      FatTerm::Config.keybindings
      FatTerm::Logger.configure
      Thread.report_on_exception = true
      if Logger.logger
        FatTerm.info("Read config from #{Config.user_config_path}")
        FatTerm.info("Read keydefs from #{Config.user_keydefs_path}")
        FatTerm.info("Read keybindings from #{Config.user_keybindings_path}")
        FatTerm.info("Logger configured to log to #{Logger.path}")
      end
    rescue FatConfig::ParseError => ex
      msg = "Terminal#preflight!: configuration error: #{ex.class}: #{ex.message}"
      warn msg
      begin
        FatTerm.error(msg, tag: :config)
      rescue StandardError
        nil
      end
      exit(1)
    end

    def start_curses!
      @ctx = FatTerm::Curses::Context.new
      @ctx.start

      @screen = FatTerm::Screen.new(rows: ::Curses.lines, cols: ::Curses.cols)
      @ctx.apply_layout(@screen)

      @renderer = FatTerm::Curses::Renderer.new(context: @ctx, screen: @screen)

      env = @env || FatTerm::Env.detect
      key_decoder = FatTerm::Curses::KeyDecoder.new(env: env)
      @event_source =
        FatTerm::Curses::EventSource.new(context: @ctx, key_decoder: key_decoder, poll_ms: 50)
      self
    end

    def stop_curses!
      @ctx&.close
    ensure
      begin
        $stdout.write("\e[0m")  # SGR reset
        $stdout.write("\e[0 q") # DECSCUSR: restore terminal default cursor
        $stdout.flush
      rescue StandardError
        # best-effort cleanup
      end
    end

    def install_default_sessions!
      pin(FatTerm::AlertSession.new)
      push(FatTerm::ShellSession.new(
             prompt: @prompt,
             on_accept: @on_accept,
             completion_proc: @completion_proc,
             history_ctx: @history_ctx
           )
          )
    end

    def resize_message?(message)
      kind, event = message
      kind == :key && event.respond_to?(:key) && event.key == :resize
    end

    def handle_resize
      rows = ::Curses.lines
      cols = ::Curses.cols
      screen.resize(rows: rows, cols: cols)
      renderer.context.apply_layout(screen)
      renderer.screen = screen
      renderer.invalidate!

      if (out = find_session(:shell) || find_session(:output))
        out.resize_output!(self) if out.respond_to?(:resize_output!)
      end

      if (top = @modal_stack.last)
        session = top[:session]
        cmds = session.handle_resize(terminal: self)
        apply_commands(cmds)
      end
    end

    def persist_sessions!
      sessions = []
      sessions << @focused_session if @focused_session
      sessions.concat(@sessions) if defined?(@sessions) && @sessions

      sessions.uniq.each do |s|
        next unless s.respond_to?(:persist!)

        s.persist!(terminal: self)
      end
    end

    def quit
      @running = false
    end

    # --- Dispatch ----------------------------------------------------------

    def dispatch_message(message)
      s = active_session
      return [] unless s

      if resize_message?(message)
        handle_resize
        render_frame
        return []
      end

      # Clear transient alerts on the next user keypress.
      if key_event_message?(message) && find_session(:alert)
        apply_command([:send, :alert, :clear, {}])
      end

      FatTerm.debug("Terminal#dispatch_message: #{message.inspect}", tag: :session)
      commands = s.update(message, terminal: self)
      FatTerm.debug("Terminal#dispatch_message: session=#{s.class} -> cmds=#{commands.inspect}", tag: :session)

      apply_commands(commands)
    end

    # Return whether message is a key message
    def key_event_message?(message)
      message.is_a?(Array) && message[0] == :key
    end

    def apply_commands(commands)
      Array(commands).each do |cmd|
        apply_command(cmd)
      end
    end

    # A command is either bound for this Terminal (first element :terminal) or
    # it's meant to be forwarded to a Session (first element :send).  This
    # method routes the command to its proper destination.
    def apply_command(cmd)
      FatTerm.debug("Terminal#apply_command(#{cmd})", tag: :session)
      return if cmd.nil?

      unless cmd.is_a?(Array) && cmd.first.is_a?(Symbol)
        raise ArgumentError, "command must be an Array starting with a Symbol, got: #{cmd.inspect}"
      end

      case cmd[0]
      when :terminal
        apply_terminal_command(cmd)
      when :send
        apply_send_command(cmd)
      else
        raise ArgumentError, "unknown command domain #{cmd[0].inspect} (cmd=#{cmd.inspect})"
      end
    end

    # Apply a command meant to be applied by this Terminal
    def apply_terminal_command(cmd)
      _, name, *rest = cmd

      case name
      when :quit
        persist_sessions!
        quit
      when :push
        session = rest.fetch(0)
        push(session)
      when :pop
        pop
      when :push_modal
        session = rest.fetch(0)
        FatTerm.debug("Terminal#apply_terminal_command(:push_modal) before size=#{@modal_stack.length}", tag: :session)
        push_modal(session, owner: focused_session)
        FatTerm.debug("Terminal#apply_terminal_command(:push_modal) after size=#{@modal_stack.length}", tag: :session)
      when :pop_modal
        FatTerm.debug("Terminal#apply_terminal_command(:pop_modal) before size=#{@modal_stack.length}", tag: :session)
        pop_modal
        FatTerm.debug("Terminal#apply_terminal_command(:pop_modal) aftersize=#{@modal_stack.length}", tag: :session)
      when :send_modal_owner
        msg = rest.fetch(0)
        owner = modal_owner
        cmds = owner ? owner.update(msg, terminal: self) : []
        apply_commands(cmds)
      when :cycle_theme
        new_theme = FatTerm::Colors::ThemeManager.cycle
        renderer.apply_theme!(new_theme)
        apply_command([:send, :alert, :show, { level: :info, message: "Theme: #{new_theme}"}])
      when :set_theme
        theme = rest.fetch(0)
        FatTerm::Colors::ThemeManager.set(theme)
        renderer.apply_theme!(theme)
        apply_command([:send, :alert, :show, { level: :info, message: "Theme: #{theme}"}])
      when :handle_resize
        handle_resize
      else
        raise ArgumentError, "unknown terminal command #{name.inspect} (cmd=#{cmd.inspect})"
      end
    end

    # Forward a command meant to be applied by a
    # [:send, recipient, message_name, payload_hash]
    def apply_send_command(cmd)
      _, recipient, message_name, payload = cmd

      session = find_session(recipient)
      raise ArgumentError, "no session registered with id=#{recipient.inspect}" unless session

      payload ||= {}
      unless payload.is_a?(Hash)
        raise ArgumentError, "send payload must be a Hash, got: #{payload.inspect}"
      end

      # Deliver as a uniform "command message" array for now.
      # Sessions can pattern-match it in #update.
      message = [:cmd, message_name, payload]

      commands = session.update(message, terminal: self)
      apply_commands(commands)
    end

    # --- Rendering ---------------------------------------------------------

    def render_frame
      renderer.begin_frame

      # Render pinned sessions first, then stack sessions.
      # Within each session, its views handle their own z-order.
      sessions = @pinned + @stack
      sessions.each do |s|
        s.view(screen: screen, renderer: renderer, terminal: self)
      end
      if (top = @modal_stack.last)
        top[:session].view(screen: screen, renderer: renderer, terminal: self)
      end

      renderer.finish_frame
    end
  end
end
