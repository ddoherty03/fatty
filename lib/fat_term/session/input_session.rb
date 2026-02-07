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
      @field.act_on(action, *args, ctx: ctx)
      :handled
    rescue ActionError
      :unhandled
    end

    private

    # Here event is what is returned by the KeyMap, which can either be a
    # simple name of an action or an Array with the action name as the first
    # element and any args as the remaining element.  Thus allows us to bind
    # keys like digit arguments to an Array that passed the digit as the
    # argument.
    def resolve_action(event)
      return [nil, []] unless keymap

      resolved = keymap.lookup(context: context, event: event)
      return [nil, []] unless resolved

      if resolved.is_a?(Array)
        [resolved[0], resolved[1..] || []]
      else
        [resolved, []]
      end
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
