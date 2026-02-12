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

    # Unbound keys land here.
    def update_key(ev, terminal:)
      []
    end

    # Bound keys land here because Session#update resolves via keymap first.
    def handle_action(action, args, terminal:, event:)
      FatTerm.log(
        "InputSession.handle_action: action=#{action.inspect} args=#{args.inspect} " \
          "key=#{event.key.inspect} ctrl=#{event.ctrl?} meta=#{event.meta?}",
        tag: :keymap,
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
      else
        @field.act_on(action, *args, env: env)
        []
      end
    rescue ActionError => e
      FatTerm.log("InputSession.handle_action: ActionError #{e.message}", tag: :keymap)
      []
    end

    private

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
