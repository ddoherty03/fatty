# lib/fatty/api/prompt.rb

module Fatty
  module PromptApi
    # The consumer can call #choose to cause an interactive popup session to
    # present the user with a series of choices to select from.
    def choose(prompt, choices:, initial_choice_idx: 0, quit_value: nil)
      items = normalize_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.map(&:first)
      popup = Fatty::PopUpSession.new(
        source: labels,
        kind: :terminal_choose,
        title: "Choose",
        message: prompt,
        prompt: "> ",
        selection: :top,
        validate_unique_labels: true,
      )

      popup.instance_variable_set(:@selected, initial_choice_idx.to_i.clamp(0, labels.length - 1))

      done = false
      result = nil

      acc_proc = ->(payload) do
        item = payload[:item]
        idx = labels.index(item)
        result = idx ? items[idx][1] : quit_value
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
            Fatty.error("Terminal#choose tick failed: #{e.class}: #{e.message}", tag: :terminal)
            dirty = true
          end

          render_frame if dirty
        end
      ensure
        render_frame
      end

      result
    end

    # A simple Yes/No chooser.
    def confirm(prompt, default: true)
      idx = default ? 0 : 1
      choose(
        prompt,
        choices: [["Yes", true], ["No", false]],
        initial_choice_idx: idx,
        quit_value: false,
      )
    end

    # The consumer can call #choose_multi to cause an interactive popup session to
    # present the user with a series of choices to select from.
    def choose_multi(prompt, choices:, quit_value: nil)
      items = normalize_choices(choices)
      raise ArgumentError, "choices must not be empty" if items.empty?

      labels = items.map(&:first)
      popup = Fatty::PopUpSession.new(
        source: labels,
        kind: :terminal_choose_multi,
        title: "Choose Many",
        message: prompt,
        prompt: "> ",
        selection: :top,
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
          h[label] = label_to_value.fetch(label, quit_value)
        end

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
            Fatty.error("Terminal#choose_multi tick failed: #{e.class}: #{e.message}", tag: :terminal)
            dirty = true
          end

          render_frame if dirty
        end
      ensure
        render_frame
      end

      result
    end

    # Create a popup to ask the user to enter an arbitrary string.  These
    # prompts will keep their own history based on the history_key, or if not
    # history_key is given, the prompt text.  If save_history is set to false, no
    # history will be recorded, which can suppress writing sensitive values
    # such as passwords to the history file.
    def prompt(prompt, initial: "", quit_value: nil, history_key: nil, save_history: true)
      history_ctx = lambda do
        base =
          if @history_ctx.respond_to?(:call)
            @history_ctx.call
          elsif @history_ctx.is_a?(Hash)
            @history_ctx
          else
            {}
          end

        base.merge(prompt: (history_key || prompt).to_s)
      end

      popup = Fatty::PromptSession.new(
        title: "Prompt",
        message: prompt,
        prompt: "> ",
        initial: initial,
        kind: :terminal_prompt,
        save_history: save_history,
        history_ctx: history_ctx,
      )
      done = false
      result = nil

      acc_proc = ->(payload) do
        result = payload[:text]
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
            Fatty.error("Terminal#prompt tick failed: #{e.class}: #{e.message}", tag: :terminal)
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

    def normalize_choices(choices)
      Array(choices).map do |choice|
        if choice.is_a?(Array) && choice.length == 2
          [choice[0].to_s, choice[1]]
        else
          [choice.to_s, choice]
        end
      end
    end
  end
end
