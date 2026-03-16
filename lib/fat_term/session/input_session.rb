# frozen_string_literal: true

module FatTerm
  class InputSession < Session
    attr_reader :field

    # @param on_accept: ->(line, session, terminal) { ... }
    def initialize(field:, keymap:, views: [], on_accept: nil)
      super(keymap: keymap, views: views)
      @field = field
      @on_accept = on_accept
    end

    def keymap_contexts
      if paging_mode?
        [:paging, :input, :terminal]
      else
        [:input, :terminal]
      end
    end

    private

    # Unbound keys land here.
    def update_key(ev, terminal:)
      []
    end

    def update_cmd(name, payload, terminal:)
      case name
      when :paste
        text = payload.fetch(:text, "").to_s
        env = action_env(terminal: terminal, event: nil)
        @field.act_on(:paste, text, env: env)
      end
      []
    end

    # Bound keys land here because Session#update resolves via keymap first.
    def handle_action(action, args, terminal:, event:)
      which =
        if event&.respond_to?(:key)
          event.key.inspect
        elsif event&.respond_to?(:mouse)
          event.mouse.inspect
        else
          nil
        end
      FatTerm.log(
        "InputSession.handle_action: #{which}", tag: :keymap,
      )
      env = action_env(terminal: terminal, event: event)
      case action.to_sym
      when :accept_line
        line = @field.accept_line
        if @on_accept
          Array(@on_accept.call(line, self, terminal))
        else
          Array(emit([:accept_line, line]))
        end
      when :cycle_theme
        [[:terminal, :cycle_theme]]
      else
        @field.act_on(action, *args, env: env)
        []
      end
    rescue ActionError => e
      FatTerm.log("InputSession.handle_action: ActionError #{e.message}", tag: :keymap)
      []
    end

    def action_env(terminal:, event:)
      ActionEnvironment.new(
        session: self,
        terminal: terminal,
        event: event,
        field: @field,
      )
    end
  end
end
