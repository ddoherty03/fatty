# frozen_string_literal: true

module Fatty
  class PromptSession < ModalSession
    attr_reader :field, :title, :message, :history

    PROMPT_POPUP_MAX_WIDTH = 120
    PROMPT_POPUP_MIN_WIDTH = 20
    PROMPT_POPUP_MARGIN    = 2

    def id = :prompt

    def initialize(initial: "", prompt: "> ", title: "Prompt", message: nil, kind: nil,
                   history_ctx: nil, history_path: :default, history: nil, save_history: true)
      super(keymap: Keymaps.emacs)
      @title = title&.to_s
      @message = message&.to_s
      @kind = kind&.to_sym
      @save_history = !!save_history
      @history = history || Fatty::History.for_path(history_path)
      @field = Fatty::InputField.new(
        prompt: prompt,
        history_kind: :prompt,
        history: @history,
        history_ctx: history_ctx,
      )
      @field.buffer.replace(initial.to_s)
      @field.buffer.bol
      @win = nil
    end

    #########################################################################################
    # Framework and Session Hooks
    #########################################################################################

    def init(terminal:)
      super
      rebuild_windows!
      []
    end

    def update(command)
      commands =
        case command.action
        when :key
          ev = command.payload.fetch(:event)
          action, args = resolve_action(ev)
          if action
            normalize_action_result(apply_action(action, args, event: ev))
          else
            []
          end
        when :paste
          text = command.payload.fetch(:text, "").to_s
          env = action_env(event: nil)
          @field.act_on(:paste, text, env: env)
          []
        else
          []
        end
      Array(commands)
    end

    def view
      return unless @win

      renderer.render_prompt_popup(session: self)
    end

    def state
      [
        title.to_s.dup.freeze,
        message.to_s.dup.freeze,
        field.prompt_text.to_s.dup.freeze,
        field.buffer.text.to_s.dup.freeze,
        field.buffer.cursor,
        field.buffer.virtual_suffix.to_s.dup.freeze,
        renderer.screen.rows,
        renderer.screen.cols,
      ]
    end

    private

    def keymap_contexts
      [:prompt, :text, :terminal]
    end

    ############################################################################################
    # Actions
    ############################################################################################

    action_on :session

    action :prompt_accept do
      text = @field.accept_line(save_history: @save_history).to_s

      [
        Command.terminal(
          :send_modal_owner,
          command: Command.session(:self, :prompt_result, kind: @kind, text: text),
        ),
        Command.terminal(:pop_modal),
      ]
    end

    desc "Cancel prompt input"
    action :prompt_cancel do
      [
        Command.terminal(
          :send_modal_owner,
          command: Command.session(:self, :prompt_cancelled, **prompt_payload),
        ),
        Command.terminal(:pop_modal),
      ]
    end

    desc "Cancel prompt if empty, otherwise delete forward"
    action :prompt_cancel_if_empty do
      if @field.buffer.text.to_s.empty?
        prompt_cancel
      else
        with_virtual_suffix_sync { @field.act_on(:delete_char_forward, env: action_env(event: nil)) }
        []
      end
    end

    def apply_action(action, args, event:)
      env = action_env(event: event)
      with_virtual_suffix_sync do
        @field.act_on(action, *args, env: env)
      end
    rescue ActionError => e
      Fatty.error("PromptSession#apply_action: ActionError #{e.message}", tag: :session)
      []
    end

    # Return the outer width and height of the window for this modal,
    # including any padding and borders.
    def geometry(cols:, rows:)
      max_w = max_width(
        cols: cols,
        margin: PROMPT_POPUP_MARGIN,
        min_width: PROMPT_POPUP_MIN_WIDTH,
      )
      max_h = max_height(rows: rows, margin: PROMPT_POPUP_MARGIN, min_height: 5)

      preferred_w = [(cols * 2 / 3).floor, 50].max

      message_width = @message.to_s.length
      prompt_width = @field.prompt_text.to_s.length + @field.buffer.text.to_s.length
      content_width = [message_width, prompt_width].max + 4

      width = clamp_width(
        [preferred_w, content_width].max,
        max_width: max_w,
        hard_max: PROMPT_POPUP_MAX_WIDTH,
      )

      extra_rows = 2
      extra_rows += 1 if @message && !@message.empty?
      height = clamp_height(
        extra_rows,
        max_height: max_h,
        min_height: 4,
      )

      [width, height]
    end

    def with_virtual_suffix_sync
      @field.sync_virtual_suffix!
      result = yield
      @field.sync_virtual_suffix!
      result
    end

    def prompt_payload
      {
        kind: @kind,
        text: @field.buffer.text.to_s,
      }
    end

    def action_env(event:)
      ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        field: @field,
        buffer: @field.buffer,
      )
    end
  end
end
