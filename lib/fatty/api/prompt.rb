# lib/fatty/api/prompt.rb

module Fatty
  module PromptApi
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

      owner = Terminal::PopupOwner.new(on_result: acc_proc, on_cancel: cancel_proc)

      begin
        push_modal(popup, owner: owner)
        render_frame

        while !done && @running
          dirty = false
          cmd = event_source.next_event
          if cmd
            apply_command(cmd)
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
  end
end
