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
        current: :top,
        validate_unique_labels: true,
      )

      popup.instance_variable_set(
        :@current,
        initial_choice_idx.to_i.clamp(0, labels.length - 1),
      )

      done = false
      result = nil
      acc_proc = ->(payload) do
        label = payload[:item]
        idx = labels.index(label)
        action = idx ? items[idx][1] : nil
        result = call_menu_action(
          action,
          label: label,
          payload: payload,
        )
        done = true
      end
      cancel_proc = -> do
        result = quit_value
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
            Fatty.error("MenuApi#menu tick failed: #{e.class}: #{e.message}", tag: :terminal)
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

    def call_menu_action(action, label:, payload:)
      result =
        if action.respond_to?(:call)
          env = CallbackEnvironment.new(
            terminal: terminal,
            output_id: output_id,
            label: label,
            payload: payload,
          )
          value =
            if action.arity.zero?
              action.call
            else
              action.call(env)
            end
          env.commands.each do |command|
            queue(command)
          end
          value
        else
          action
        end
      result
    end
  end
end
