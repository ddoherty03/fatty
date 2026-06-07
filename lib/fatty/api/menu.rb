# lib/fatty/api/prompt.rb

module Fatty
  module MenuApi
    # Present a chooser whose selected value is executed.
    #
    # choices may be:
    #   [["Label", proc { ... }], ...]
    # or:
    #   { "Label" => proc { ... } }
    #
    # The proc may accept:
    #   0 args
    #   terminal:
    #   terminal:, label:
    #   terminal:, label:, payload:
    def menu(prompt, choices:, initial_choice_idx: 0, quit_value: nil)
      items = normalize_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.map(&:first)
      popup = Fatty::PopUpSession.new(
        source: labels,
        kind: :terminal_menu,
        title: "Menu",
        message: prompt,
        prompt: "> ",
        selection: :top,
        validate_unique_labels: true,
      )

      popup.instance_variable_set(:@selected, initial_choice_idx.to_i.clamp(0, labels.length - 1))

      done = false
      result = nil
      menu_session = active_session
      acc_proc = ->(payload) do
        label = payload[:item]
        idx = labels.index(label)
        action = idx ? items[idx][1] : nil
        result = call_menu_action(
          action,
          session: menu_session,
          label: label,
          payload: payload,
        )
        done = true
      end
      cancel_proc = -> do
        result = quit_value
        done = true
      end

      owner = PopupOwner.new(on_result: acc_proc, on_cancel: cancel_proc)
      begin
        push_modal(popup, owner: owner)
        render_frame

        while !done && @running
          dirty = false
          msg = event_source.next_event

          if msg
            dispatch_message(msg)
            dirty = true
          end

          s = active_session
          begin
            tick_dirty = !!s&.tick
            dirty ||= tick_dirty
          rescue StandardError => e
            Fatty.error("Terminal#menu tick failed: #{e.class}: #{e.message}", tag: :terminal)
            dirty = true
          end

          render_frame if dirty
        end
      ensure
        render_frame
      end
      result
    end

    private

    def call_menu_action(action, session:, label:, payload:)
      if action.respond_to?(:call)
        env = MenuEnv.new(
          terminal: self,
          session: session,
          label: label,
          payload: payload,
        )
        if action.arity.zero?
          action.call
        else
          action.call(env)
        end
      else
        action
      end
    end
  end
end
