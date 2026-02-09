# frozen_string_literal: true

module FatTerm
  class InputSession < Session
    attr_reader :field

    # on_accept: ->(line, session, terminal) { ... }
    def initialize(field:, keymap:, context: :input, views: [], on_accept: nil)
      super(keymap: keymap, context: context, views: views)
      @field = field
      @on_accept = on_accept
    end

    # Unbound keys land here.
    def update_key(ev, terminal:)
      if ev.text && !ev.text.empty? && ev.text != "\n" && ev.text != "\r"
        ctx = action_context(terminal: terminal, event: ev)
        @field.act_on(:insert, ev.text, ctx: ctx)
      end
      []
    end

    # Bound keys land here because Session#update resolves via keymap first.
    def handle_action(action, args, terminal:, event:)
      FatTerm.log(
        "InputSession.handle_action: action=#{action.inspect} args=#{args.inspect} key=#{event.key.inspect} ctrl=#{event.ctrl?} meta=#{event.meta?}",
        tag: :keymap
      )

      if action.to_sym == :accept_line
        line = @field.accept_line
        return Array(@on_accept ? @on_accept.call(line, self, terminal) : emit([:accept_line, line]))
      end

      ctx = action_context(terminal: terminal, event: event)
      @field.act_on(action, *args, ctx: ctx)
      []
    rescue ActionError => e
      FatTerm.log("InputSession.handle_action: ActionError #{e.message}", tag: :keymap)
      []
    end

    private

    def action_context(terminal:, event:)
      # Adapt this to whatever ActionContext class you already have.
      if defined?(ActionContext)
        ActionContext.new(session: self, terminal: terminal, event: event, field: @field)
      else
        { session: self, terminal: terminal, event: event, field: @field }
      end
    end
  end
end
