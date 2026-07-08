# lib/fatty/api/prompt.rb

module Fatty
  module MenuApi
    def menu(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)
      items = normalize_menu_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.keys
      popup = Fatty::PopUpSession.new(
        source: labels,
        kind: :terminal_menu,
        title: "Menu",
        message: prompt,
        prompt: "> ",
        current: :top,
        validate_unique_labels: true,
        history: terminal.history,
        history_kind: :popup_filter,
        history_ctx: { kind: :popup_filter, popup: :menu, prompt: prompt.to_s },
      )
      popup.instance_variable_set(
        :@current,
        initial_choice_idx.to_i.clamp(0, labels.length - 1),
      )

      done = false
      result = nil
      acc_proc = ->(payload) do
        label = payload[:item]
        action = items[label]

        result =
          if action
            call_menu_action(action, label: label)
          else
            cancel_value
          end

        done = true
      end
      cancel_proc = -> do
        result = cancel_value
        done = true
      end
      owner = Fatty::Terminal::PopupOwner.new(
        on_result: acc_proc,
        on_cancel: cancel_proc,
      )

      begin
        terminal.apply_command(
          Command.terminal(:push_modal, session: popup, owner: owner),
        )
        terminal.render_frame

        while !done && terminal.running?
          dirty = false
          command = terminal.event_source.next_event
          if command
            terminal.apply_command(command)
            dirty = true
          end

          begin
            dirty ||= !!terminal.tick_active_session
          rescue StandardError => e
            Fatty.error(
              "MenuApi#menu tick failed: #{e.class}: #{e.message}",
              tag: :terminal,
            )
            dirty = true
          end

          terminal.render_frame if dirty
        end
      ensure
        terminal.render_frame
      end
      result
    end

    private

    # simplecov:disable

    def normalize_menu_choices(choices)
      unless choices.is_a?(Hash)
        raise ArgumentError, "menu choices must be a Hash of label => callable"
      end

      choices.each_with_object({}) do |(label, action), normalized|
        unless action.respond_to?(:call)
          raise ArgumentError, "menu choice #{label.inspect} is not callable"
        end
        normalized[label.to_s] = action
      end
    end

    def call_menu_action(action, label:)
      action.call(self, label)
    end
  end
end
