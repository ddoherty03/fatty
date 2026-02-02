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

    def initialize(screen:, renderer:, event_source:)
      @screen = screen
      @renderer = renderer
      @event_source = event_source

      @running = false

      @stack = []          # focus stack (top receives input)
      @pinned = []         # always rendered, never focused unless you choose
      @sessions_by_id = {} # id => session
      @logger = FatTerm::Logger.configure(level: FatTerm::Config.config[:log][:level])
    end

    # --- Session management ------------------------------------------------

    def push(session)
      @stack << session
      register(session)
      _model, commands = session.init(terminal: self)
      apply_commands(commands)
      session
    end

    def pop
      @stack.pop
    end

    def pin(session)
      @pinned << session
      register(session)
      _model, commands = session.init(terminal: self)
      apply_commands(commands)
      session
    end

    def focused_session
      @stack.last
    end

    def register(session)
      return unless session.respond_to?(:id)
      return if session.id.nil?

      @sessions_by_id[session.id] = session
    end

    def find_session(id)
      @sessions_by_id[id]
    end

    # --- Runtime -----------------------------------------------------------

    def go
      @running = true

      # First frame, so the UI appears before the first input event.
      render_frame

      while @running
        msg = event_source.next_event
        if msg
          dispatch_message(msg)
        else
          # If you later add ticks, you can inject TickEvent here.
          # For now: just keep looping.
        end

        render_frame
      end
    end

    def quit
      @running = false
    end

    # --- Dispatch ----------------------------------------------------------

    def dispatch_message(message)
      s = focused_session
      return unless s

      # Clear transient alerts on the next user keypress.
      if key_event_message?(message) && find_session(:alert)
        apply_command([:send, :alert, :clear, {}])
      end

      model, commands = s.update(message, terminal: self)
      # Charm convention: model returned, but we don't need to replace the object
      # unless you later choose immutable sessions.
      register(model) if model && model != s

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

    def apply_command(cmd)
      return if cmd.nil?

      # Allow sessions still returning non-normalized forms during migration.
      # If someone passes [self, commands] here by mistake, unpack it.
      if cmd.is_a?(Array) && cmd.length == 2 && cmd[0].respond_to?(:update)
        apply_commands(cmd[1])
        return
      end

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

    def apply_terminal_command(cmd)
      _, name, *rest = cmd

      case name
      when :quit
        quit
      when :push
        session = rest.fetch(0)
        push(session)
      when :pop
        pop
      else
        raise ArgumentError, "unknown terminal command #{name.inspect} (cmd=#{cmd.inspect})"
      end
    end

    # [:send, target_id, message_name, payload_hash]
    def apply_send_command(cmd)
      _, target_id, message_name, payload = cmd

      session = find_session(target_id)
      raise ArgumentError, "no session registered with id=#{target_id.inspect}" unless session

      payload ||= {}
      unless payload.is_a?(Hash)
        raise ArgumentError, "send payload must be a Hash, got: #{payload.inspect}"
      end

      # Deliver as a uniform "command message" array for now.
      # Sessions can pattern-match it in #update.
      message = [:cmd, message_name, payload]

      _model, commands = session.update(message, terminal: self)
      apply_commands(commands)
    end

    # --- Rendering ---------------------------------------------------------

    def render_frame
      # Render pinned sessions first, then stack sessions.
      # Within each session, its views handle their own z-order.
      sessions = @pinned + @stack
      sessions.each do |s|
        s.view(screen: screen, renderer: renderer, terminal: self)
      end
    end
  end
end
