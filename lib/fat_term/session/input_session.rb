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

    # It receives semantic events and applies actions.
    #
    # Return :handled or :unhandled.
    def update(event, terminal:)
      action, args = resolve_action(event)
      return :unhandled unless action

      if action.to_sym == :accept_line
        line = @field.accept_line
        @on_accept ? @on_accept.call(line, self, terminal) : emit([:accept_line, line])
        return :handled
      end

      ctx = action_context(terminal:, event:)
      Actions.call(action, ctx, *args)
      :handled
    rescue ActionError
      :unhandled
    end

    private

    # Keep this as a seam: today you might delegate to Terminal;
    # later Terminal can become the sole binding resolver.
    def resolve_action(event, terminal:)
      return unless keymap

      keymap.lookup(context: context, event: event)
    end

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
