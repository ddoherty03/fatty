# frozen_string_literal: true

require_relative 'terminal/popup_owner'

module Fatty
  # Fatty aims at providing a full-featured, curses-based platform for
  # REPL-style interaction with
  #  - command-line editing (by default using Emacs-like keybindings),
  #  - an output pane for normal output, a status pane for out-of-band
  #    messages to the user, and an alert pane for library-related error or
  #    information messages,
  #  - history traversal and context-aware history,
  #  - command completions based on input-so-far,
  #  - popup facilities for things such as prompting the user for a string,
  #    selecting one or more values from a list, selecting user-defined
  #    actions from a menu, and more,
  #  - a variety of progress indicators to keep the user informed about what's
  #    happening in a long-running process.
  #  - scrolling and searching long output to the output pane,
  #  - rendering markdown text in the output pane,
  #  - a theming system with several pre-defined color themes and facilities
  #    for the user to add their own,
  #  - a way to define keys that curses does not recognize and assign actions
  #    to them, including actions the user defines
  #  - rendering ANSI colored text to the output pane and the status pane,
  #  - a way to suspend Fatty and exit to your real terminal and come back to
  #    where you left off when you exit that terminal session.
  #
  # In other words, Fatty does much of the heavy lifting needed for a
  # comfortable, full-featured interactive application.
  #
  # Fatty does not purport to be a "terminal" program but sits on top of them
  # using curses and truecolor rendering into your normal terminal.
  #
  # Terminal is the main entry point. A library user normally creates a
  # Terminal, configures the prompt, completion, history, and accept callback,
  # then calls #go.
  #
  # Initialization options:
  #
  # - prompt :: either a fixed string or a proc that, when called, returns a
  #   string to be used as the command-line prompt;
  # - on_accept :: a proc that takes the edited line and performs some action
  #   on it; the proc will have available to it a variable, `env`, that
  #   contains an AcceptEnv object containing a reference to the ShellSession
  #   and Terminal so that it can call actions on them, most commonly
  #   `env.session.append_output(text)` to write output to the output pane;
  # - completion_proc :: a proc that returns an Array of strings based on the
  #   input-so-far to suggest completions that can be inserted at that point;
  # - history_path :: a path or sentinel describing input history is loaded
  #   from and persisted;
  # - history_ctx :: a proc that provides a "context" for history so that it
  #   can be "favored" by history requests in the same context later;
  # - env :: an optional Fatty::Env describing the runtime environment; when
  #   omitted, Fatty will detect it with `Fatty::Env.detect`.
  #
  class Terminal
    SCROLL_RENDER_THROTTLE = 0.05

    attr_reader :screen, :focused_session, :renderer, :event_source, :env
    attr_reader :status_session, :alert_session


    def initialize(prompt: "> ",
                   on_accept: nil,
                   completion_proc: nil,
                   history_path: :default,
                   history_ctx: nil,
                   env: nil)
      @prompt = Prompt.ensure(prompt)
      @on_accept = on_accept
      @completion_proc = completion_proc
      @history_path = history_path
      @history_ctx = history_ctx
      @env = env

      @running = false
      @pinned = []
      @sessions = []
      @sessions_by_id = {}
      @modal_stack = []
    end

    # --- Runtime -----------------------------------------------------------
    # Run the terminal.
    #
    # This method owns Fatty's main lifecycle:
    #
    # - load configuration and logging;
    # - start curses and build the screen, renderer, and event source;
    # - install the default permanent sessions;
    # - enter the event loop;
    # - restore the real terminal and persist session state on exit.
    #
    # The event loop has two sources of work. First, it polls the EventSource
    # for user input, resize events, and other terminal events. Any event is
    # routed to the active session, whose #update method may mutate session
    # state and return commands for Terminal to process. Second, the active
    # session is ticked once per loop so it can animate, poll, or otherwise
    # mark itself dirty without receiving a key event.
    #
    # Whenever an event or tick changes state, Terminal schedules a render. Most
    # renders happen immediately. The exception is fast scrolling in the normal
    # curses renderer, where repeated output updates may be throttled to avoid
    # excessive redraws. Truecolor rendering and direct user input are rendered
    # immediately.
    #
    # Fatal errors are logged and re-raised, but cleanup still runs: curses is
    # stopped so the real terminal is restored, and persistent sessions are given
    # a chance to save their state.
    def go
      preflight!
      start_curses!
      install_default_sessions!

      @running = true
      last_render = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pending_scroll_render = false
      render_frame

      # For performance logging
      perf_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      loop_count = 0
      event_count = 0
      tick_dirty_count = 0
      render_count = 0
      deferred_count = 0
      frame_ms = 0.0

      while @running
        loop_count += 1

        dirty = false
        immediate = false

        msg = event_source.next_event
        if msg
          dispatch_message(msg)
          dirty = true
          immediate = true
        end

        s = active_session
        begin
          tick_dirty = !!s&.tick
          tick_dirty_count += 1 if tick_dirty
          dirty ||= tick_dirty
        rescue StandardError => e
          Fatty.error("Terminal#go tick failed: #{e.class}: #{e.message}", tag: :terminal)
          dirty = true
          immediate = true
        end

        if dirty
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if immediate || renderer.context.truecolor || !scrolling_output?
            render_frame
            last_render = now
            pending_scroll_render = false
            render_count += 1
          elsif now - last_render >= SCROLL_RENDER_THROTTLE
            render_frame
            last_render = now
            pending_scroll_render = false
            render_count += 1
          else
            pending_scroll_render = true
            deferred_count += 1
          end
        elsif pending_scroll_render
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if now - last_render >= SCROLL_RENDER_THROTTLE
            render_frame
            last_render = now
            pending_scroll_render = false
            render_count += 1
          end
        end

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if now - perf_started_at >= 1.0
          avg_frame_ms =
            if render_count.zero?
              0.0
            else
              (frame_ms / render_count).round(2)
            end

          # Performance logging
          Fatty.debug(
            "perf loops=#{loop_count} events=#{event_count} " \
            "tick_dirty=#{tick_dirty_count} renders=#{render_count} " \
            "deferred=#{deferred_count} avg_frame_ms=#{avg_frame_ms} " \
            "scrolling=#{scrolling_output?}",
            tag: :perf,
          )
          perf_started_at = now
          loop_count = 0
          event_count = 0
          tick_dirty_count = 0
          render_count = 0
          deferred_count = 0
          frame_ms = 0.0
        end
      end
    rescue => e
      Fatty.error("Terminal#go fatal error: #{e.class}: #{e.message}", tag: :terminal)
      Fatty.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      raise
    ensure
      begin
        stop_curses!
      rescue => e
        Fatty.error("Terminal#go stop_curses! failed: #{e.class}: #{e.message}", tag: :terminal)
        Fatty.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      end

      begin
        persist_sessions!
      rescue => e
        Fatty.error("Terminal#go persist_sessions! failed: #{e.class}: #{e.message}", tag: :terminal)
        Fatty.error(e.backtrace.join("\n"), tag: :terminal) if e.backtrace
      end
    end

    # --- Suspension  ------------------------------------------------

    # Suspend fatty and run the block in the normal terminal, then restore
    # fatty's terminal on exit.
    def suspend
      stop_curses!
      yield
    ensure
      start_curses!
      refresh_layout!
      render_frame
    end

    # --- Rendering ---------------------------------------------------------

    def render_frame
      renderer.begin_frame

      @sessions.each do |session|
        session.view(renderer: renderer)
      end
      if (top = @modal_stack.last)
        top[:session].view(renderer: renderer)
      end
      restore_active_cursor
      renderer.finish_frame
    end

    private

    # * Session management
    #
    # Terminal coordinates a small set of Session objects. A session is a UI
    # component with three standard phases:
    #
    # - init :: receive the terminal and initialize session state;
    # - update :: receive events or commands, mutate session state accordingly,
    #   and, optionally, return commands requesting that Terminal perform
    #   additional actions or route commands to other sessions;
    # - view :: render the session's current state.
    #
    # Terminal is not itself a Session subclass, but it acts as the coordinator
    # for all sessions. It routes input events to the active session, routes
    # explicit commands either to itself or to a named session, and renders the
    # sessions in a fixed order.
    #
    # Terminal keeps sessions in two groups:
    #
    # - permanent sessions :: a collection of always-present sessions. One
    #   permanent session is designated the focused session and receives
    #   keyboard input whenever no modal session is active. In the standard
    #   configuration this is a ShellSession. Other permanent sessions, such
    #   as StatusSession and AlertSession, are output-only sessions that do
    #   not receive input focus.
    # - modal sessions :: temporary sessions displayed above the permanent
    #   sessions, usually as popups. While a modal session is present, it
    #   becomes the active session and receives input first. The modal stack
    #   also records an owner so that modal results can be sent back to the
    #   session or helper that opened the modal.
    #
    # Rendering follows the same layering: permanent sessions are rendered
    # first, followed by the top modal session.
    #
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
    #   [:send, :alert, :show, { level: :warn, message: "No matches" }]
    #   [:send, :alert, :clear, {}]

    def install_session(session, focus: false)
      @sessions << session
      register(session)
      @focused_session = session if focus

      commands = session.init(terminal: self)
      apply_commands(commands)
      session
    end

    def register(session)
      return unless session.respond_to?(:id)
      return if session.id.nil?

      @sessions_by_id[session.id] = session
    end

    def install_default_sessions!
      install_session(Fatty::ShellSession.new(
                        prompt: @prompt,
                        on_accept: @on_accept,
                        completion_proc: @completion_proc,
                        history_path: @history_path,
                        history_ctx: @history_ctx,
                      ),
                      focus: true)
      @status_session = install_session(Fatty::StatusSession.new)
      @alert_session = install_session(Fatty::AlertSession.new)
    end

    def push_modal(session, owner:)
      @modal_stack << { session: session, owner: owner }
      msg = "Terminal#push_modal: size=#{@modal_stack.length} session=#{session.class} object_id=#{session.object_id}"
      Fatty.debug(msg, tag: :session)

      @renderer.invalidate! if defined?(@renderer) && @renderer
      commands = session.init(terminal: self)
      apply_commands(commands)
    end

    def pop_modal
      top = @modal_stack.pop
      msg = "Terminal#pop_modal: size=#{@modal_stack.length} popped=#{top && top[:session].class}"
      Fatty.debug(msg, tag: :session)
      session = top && top[:session]

      session.close if session&.respond_to?(:close)
      @renderer&.invalidate!
      nil
    end

    # If we have modal sessions, the most recent one is active; otherwise, the
    # focused_session, i.e., the ShellSession.
    def active_session
      top = @modal_stack.last
      top ? top[:session] : focused_session
    end

    # Return the owner of the top modal session without modifying the stack.
    def modal_owner
      top = @modal_stack.last
      top && top[:owner]
    end

    # Return the Session object associated with `id`, which will be a symbol
    # like :status or :alert.
    def find_session(id)
      @sessions_by_id[id]
    end

    # * Initialization
    #
    # These methods get Fatty started by reading the config, preparing
    # Curses, the Logger, installing key definitions and mappings, and
    # installing themes.
    #
    def preflight!
      Fatty::Config.config
      Fatty::Logger.configure
      if Fatty::Logger.logger
        Fatty.info("Fatty #{Fatty::VERSION} loaded from #{__dir__}", tag: :config)
        Fatty.info("Logger configured to log to #{Logger.path}", tag: :config)
        Fatty.info("Read config from #{Config.user_config_path}", tag: :config)
        Fatty.info("Config", config: Config.config, tag: :config)
      end
      Fatty::Config.keydefs
      Fatty::Config.keybindings
      Fatty::Config.install_default_themes!
      Fatty::Themes::Manager.load!
      Thread.report_on_exception = true
    rescue FatConfig::ParseError => ex
      msg = "Terminal#preflight!: configuration error: #{ex.class}: #{ex.message}"
      warn msg
      begin
        Fatty.error(msg, tag: :config)
      rescue StandardError
        nil
      end
      exit(1)
    end

    def start_curses!
      @ctx = Fatty::Curses::Context.new
      @ctx.start

      @screen = Fatty::Screen.new(rows: ::Curses.lines, cols: ::Curses.cols, status_rows: 0)
      @ctx.apply_layout(@screen)

      @renderer =
        if @ctx.truecolor
          Fatty::Renderer::Truecolor.new(context: @ctx, screen: @screen, palette: @ctx.palette)
        else
          Fatty::Renderer::Curses.new(context: @ctx, screen: @screen, palette: @ctx.palette)
        end
      @renderer.sync_backgrounds! if @ctx.truecolor

      @env ||= Fatty::Env.detect
      key_decoder = Fatty::Curses::KeyDecoder.new(env: @env)
      @event_source =
        Fatty::Curses::EventSource.new(context: @ctx, key_decoder: key_decoder, poll_ms: 50)
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

    def scrolling_output?
      session = active_session
      pager =
        if session.respond_to?(:pager)
          session.pager
        end

      pager && pager.mode == :scrolling
    end

    def refresh_layout!
      screen.resize(
        rows: @ctx.rows,
        cols: @ctx.cols,
        status_rows: status_session&.rows,
      )
      @ctx.apply_layout(screen)
      renderer.screen = screen
      if (session = focused_session)
        session.resize_output! if session.respond_to?(:resize_output!)
      end
      if (top = @modal_stack.last)
        session = top[:session]
        apply_commands(session.handle_resize) if session.respond_to?(:handle_resize)
      end
      renderer.sync_backgrounds! if renderer.context.truecolor
      renderer.invalidate!
    end

    def resize_message?(message)
      kind, event = message
      kind == :key && event.respond_to?(:key) && event.key == :resize
    end

    def handle_resize
      rows = ::Curses.lines
      cols = ::Curses.cols
      size = [rows, cols]

      return [] if size == @last_handled_resize_size

      @last_handled_resize_size = size

      did_resize_term = false

      # ncurses must be told to finalize internal resize state before we
      # draw ANSI output. Without this, ANSI writes after resize may be
      # ignored or clipped. Guarded to avoid recursive resize storms.
      unless @inside_resize_term
        @inside_resize_term = true
        did_resize_term = true

        # Use ncurses' high-level resize finalizer. This updates stdscr/curscr
        # and ncurses bookkeeping before we rebuild Fatty's own layout and draw
        # the ANSI overlay. resize_term is lower-level and is not equivalent here.
        ::Curses.resizeterm(rows, cols)
      end

      renderer.clear_physical_screen! if renderer.context.truecolor

      screen.resize(rows: rows, cols: cols, status_rows: status_session&.rows)
      renderer.context.apply_layout(screen)
      renderer.screen = screen
      renderer.sync_backgrounds! if renderer.context.truecolor
      renderer.invalidate!

      if (out = focused_session)
        out.resize_output! if out.respond_to?(:resize_output!)
      end

      if (top = @modal_stack.last)
        session = top[:session]
        cmds = session.handle_resize
        apply_commands(cmds)
      end
      []
    ensure
      @inside_resize_term = false if did_resize_term
    end

    def persist_sessions!
      sessions = []
      sessions << @focused_session if @focused_session
      sessions.concat(@sessions) if defined?(@sessions) && @sessions

      sessions.uniq.each do |s|
        next unless s.respond_to?(:persist!)

        s.persist!
      end
    end

    def quit
      @running = false
    end

    # --- Dispatch ----------------------------------------------------------

    def dispatch_message(message)
      s = active_session
      return [] unless s

      if user_interaction_message?(message)
        apply_command(Command.session(:status, :clear)) if status_session&.visible?
        apply_command(Command.session(:alert, :clear)) if alert_session&.visible?
      end

      Fatty.debug("Terminal#dispatch_message: #{message.inspect}", tag: :session)
      commands = s.update(message)
      Fatty.debug("Terminal#dispatch_message: session=#{s.class} -> cmds=#{commands.inspect}", tag: :session)

      apply_commands(commands)
    end

    def user_interaction_message?(message)
      key_event_message?(message) && !resize_message?(message)
    end

    # Return whether message is a key message
    def key_event_message?(message)
      message.is_a?(Array) && message[0] == :key
    end

    def apply_commands(commands)
      commands = [commands] if commands.is_a?(Fatty::Command)
      Array(commands).each do |cmd|
        apply_command(cmd)
      end
    end

    # A command is either bound for this Terminal or it's meant to be
    # forwarded to a Session.  This method routes the command to its proper
    # destination.
    def apply_command(command)
      command = Fatty::Command.coerce(command)
      Fatty.debug("Terminal#apply_command(#{command})", tag: :session)

      if command.terminal?
        apply_terminal_command(command)
      else
        apply_session_command(command)
      end
    end

    # Apply a command meant to be applied by this Terminal.
    def apply_terminal_command(command)
      case command.action
      when :quit
        persist_sessions!
        quit
      when :refresh_layout
        refresh_layout!
      when :push_modal
        session = command.payload.fetch(:session)
        Fatty.debug("Terminal#apply_terminal_command(:push_modal) before size=#{@modal_stack.length}", tag: :session)
        push_modal(session, owner: focused_session)
        Fatty.debug("Terminal#apply_terminal_command(:push_modal) after size=#{@modal_stack.length}", tag: :session)
      when :pop_modal
        Fatty.debug("Terminal#apply_terminal_command(:pop_modal) before size=#{@modal_stack.length}", tag: :session)
        pop_modal
        Fatty.debug("Terminal#apply_terminal_command(:pop_modal) after size=#{@modal_stack.length}", tag: :session)
      when :send_modal_owner
        message = command.payload.fetch(:message)
        owner = modal_owner
        commands = owner ? owner.update(message) : []
        apply_commands(commands)
      when :choose_theme
        choose_theme
      when :cycle_theme
        new_theme = Fatty::Themes::Manager.cycle
        renderer.apply_theme!(new_theme)
        apply_command(
          Command.session(
            :alert,
            :show,
            level: :info,
            text: "Theme: #{new_theme}",
          ))
      when :set_theme
        theme = command.payload.fetch(:theme)
        Fatty::Themes::Manager.set(theme)
        renderer.apply_theme!(theme)
        apply_command(
          Command.session(
            :alert,
            :show,
            level: :info,
            text: "Theme: #{new_theme}",
          ))
      when :handle_resize
        handle_resize
      else
        raise ArgumentError, "unknown terminal command #{command.action.inspect} (cmd=#{command.inspect})"
      end
    end

    # Forward a command meant to be applied by a session.
    def apply_session_command(command)
      session = find_session(command.id)
      raise ArgumentError, "no session registered with id=#{command.id.inspect}" unless session

      unless command.payload.is_a?(Hash)
        raise ArgumentError, "session command payload must be a Hash, got: #{command.payload.inspect}"
      end

      # Command is Terminal's routing object. Session#update, however, still
      # speaks in event/message arrays so that command messages and key/mouse
      # events travel through the same update path. The :cmd envelope tells
      # Session#update to dispatch to #update_cmd.
      message = [:cmd, command.action, command.payload]
      commands = session.update(message)
      apply_commands(commands)
    end

    def prompt_history
      @prompt_history ||= Fatty::History.new(path: :default)
    end

    def restore_active_cursor
      if @modal_stack && !@modal_stack.empty?
        session = @modal_stack.last[:session]

        if session.respond_to?(:pager_active?) && session.pager_active?
          ::Curses.curs_set(0)
          return
        end

        if session.respond_to?(:win) && session.respond_to?(:field) && session.field
          win = session.win
          unless win
            ::Curses.curs_set(0)
            return
          end

          begin
            maxy = win.maxy
            maxx = win.maxx
          rescue RuntimeError
            ::Curses.curs_set(0)
            return
          end

          # If the popup is too small to place a cursor safely, just hide it.
          if maxy < 3 || maxx < 3
            ::Curses.curs_set(0)
            return
          end

          ::Curses.curs_set(1)

          cursor_x = session.field.cursor_x
          cursor_x = 0 if cursor_x.nil?

          if session.is_a?(Fatty::PopUpSession)
            input_row = maxy - 2
            cursor_x = cursor_x.clamp(0, [maxx - 3, 0].max)
            begin
              win.setpos(input_row, 1 + cursor_x)
            rescue RuntimeError
              ::Curses.curs_set(0)
            end
          elsif session.is_a?(Fatty::PromptSession)
            message_rows = session.message && !session.message.empty? ? 1 : 0
            input_row = 1 + message_rows
            cursor_x = cursor_x.clamp(0, [maxx - 3, 0].max)
            begin
              win.setpos(input_row, 1 + cursor_x)
            rescue RuntimeError
              ::Curses.curs_set(0)
            end
          else
            ::Curses.curs_set(0)
          end

          return
        end

        ::Curses.curs_set(0)
        return
      end

      session = active_session
      return unless session

      if session.respond_to?(:pager_active?) && session.pager_active?
        ::Curses.curs_set(0)
        return
      end

      return unless session.respond_to?(:field) && session.field

      ::Curses.curs_set(1)
      renderer.restore_cursor(session.field)
    end

    def choose_theme
      current = Fatty::Themes::Manager.current
      names = Fatty::Themes::Manager.theme_names
      ordered = [current] + (names - [current])

      chooser = Fatty::PopUpSession.new(
        source: ordered,
        kind: :theme_chooser,
        title: "Themes",
        prompt: "Theme: ",
        selection: :top,
      )
      owner = PopupOwner.new(
        on_result: ->(payload) do
          theme = payload[:item]
          Fatty::Command.terminal(:set_theme, theme: theme)
        end,
        on_cancel: -> do
          Fatty::Command.terminal(:set_theme, theme: current)
        end,
      )
      push_modal(chooser, owner: owner)
    end
  end
end
