# frozen_string_literal: true

module Fatty
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
        [:paging, :text, :terminal]
      else
        [:text, :terminal]
      end
    end

    private

    # Unbound keys land here.
    def update_key(ev)
      []
    end

    def update_cmd(name, payload)
      case name
      when :paste
        text = payload.fetch(:text, "").to_s
        env = action_env(event: nil)
        field.act_on(:paste, text, env: env)
      end
      []
    end

    # Bound keys land here because Session#update resolves via keymap first.
    def handle_action(action, args, event:)
      which =
        if event&.respond_to?(:key)
          event.key.inspect
        elsif event&.respond_to?(:mouse)
          event.mouse.inspect
        else
          nil
        end
      Fatty.debug("InputSession#handle_action: #{which}", tag: :session)
      env = action_env(event: event)
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
        with_virtual_suffix_sync do
          Fatty::Actions.call(action, env, *args)
        end
        []
      end
    rescue ActionError => e
      Fatty.error("InputSession#handle_action: ActionError #{e.message}", tag: :session)
      []
    end

    def action_env(event:)
      ActionEnvironment.new(
        session: self,
        terminal: terminal,
        event: event,
        field: @field,
      )
    end

    def with_virtual_suffix_sync
      @field.sync_virtual_suffix!
      result = yield
      @field.sync_virtual_suffix!
      result
    end
  end
end
