# frozen_string_literal: true

module Fatty
  module ChooseApi
    # The consumer can call #choose to cause an interactive popup session to
    # present the user with a series of choices to select from.
    def choose(prompt, choices:, initial_choice_idx: 0, cancel_value: nil)
      items = normalize_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.map(&:first)
      popup = PopUpSession.new(
        source: labels,
        kind: :terminal_choose,
        title: "Choose",
        message: prompt,
        prompt: "> ",
        current: :top,
        show_counts: false,
        validate_unique_labels: true,
      )
      popup.instance_variable_set(:@current, initial_choice_idx.to_i.clamp(0, labels.length - 1))

      done = false
      result = nil

      acc_proc = ->(payload) do
        item = payload[:item]
        idx = labels.index(item)
        result = idx ? items[idx][1] : cancel_value
        done = true
      end
      cancel_proc = -> do
        result = cancel_value
        done = true
      end
      owner = Terminal::PopupOwner.new(on_result: acc_proc, on_cancel: cancel_proc)

      begin
        terminal.apply_command(Fatty::Command.terminal(:push_modal, session: popup, owner: owner))
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
            Fatty.error("PromptApi#choose tick failed: #{e.class}: #{e.message}", tag: :terminal)
            dirty = true
          end

          terminal.render_frame if dirty
        end
      ensure
        terminal.render_frame
      end
      result
    end

    # A simple Yes/No chooser.
    def confirm(prompt, yes_label: "Yes", no_label: "No", cancel_value: false)
      choose(
        prompt,
        choices: { yes_label => true, no_label => false },
        cancel_value: cancel_value,
      )
    end

    # The consumer can call #choose_multi to cause an interactive popup session to
    # present the user with a series of choices to select from.
    def choose_multi(prompt, choices:, cancel_value: nil)
      items = normalize_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.map(&:first)
      popup = PopUpSession.new(
        source: labels,
        kind: :terminal_choose_multi,
        title: "Choose Many",
        message: prompt,
        prompt: "> ",
        current: :top,
        show_counts: true,
        selection_mode: :multiple,
        validate_unique_labels: true,
      )

      done = false
      result = nil

      label_to_value = items.to_h
      acc_proc = ->(payload) do
        selected = payload[:items] || {}
        result =
          selected.each_with_object({}) do |(label, _), h|
          h[label] = label_to_value.fetch(label, cancel_value)
        end
        done = true
      end
      cancel_proc = -> do
        result = cancel_value
        done = true
      end
      owner = Terminal::PopupOwner.new(on_result: acc_proc, on_cancel: cancel_proc)

      begin
        terminal.apply_command(Fatty::Command.terminal(:push_modal, session: popup, owner: owner))
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
            Fatty.error("Terminal#choose_multi tick failed: #{e.class}: #{e.message}", tag: :terminal)
            dirty = true
          end

          terminal.render_frame if dirty
        end
      ensure
        terminal.render_frame
      end
      result
    end
  end
end
