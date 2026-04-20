# frozen_string_literal: true

module FatTerm
  class PromptSession < Session
    attr_reader :win, :field, :title, :message, :history

    PROMPT_POPUP_MAX_WIDTH = 120
    PROMPT_POPUP_MIN_WIDTH = 20
    PROMPT_POPUP_MARGIN    = 2

    def id = :prompt

    def initialize(initial: "", prompt: "> ", title: "Prompt", message: nil, kind: nil,
                   history_ctx: nil, history_path: :default)
      super(keymap: Keymaps.emacs, views: [])
      @title = title&.to_s
      @message = message&.to_s
      @kind = kind&.to_sym

      @history = FatTerm::History.for_path(history_path)
      @field = FatTerm::InputField.new(
        prompt: prompt,
        history: @history,
        history_kind: :prompt,
        history_ctx: history_ctx,
      )
      @field.buffer.replace(initial.to_s)

      @win = nil
    end

    def keymap_contexts
      [:input]
    end

    def init(terminal:)
      rebuild_windows!(terminal)
      []
    end

    def view(screen:, renderer:, terminal:)
      return unless @win

      renderer.render_prompt_popup(session: self)
    end

    def handle_resize(terminal:)
      rebuild_windows!(terminal)
      []
    end

    def handle_action(action, args, terminal:, event:)
      env = action_env(terminal: terminal, event: event)

      case action.to_sym
      when :interrupt
        [
          [:terminal, :send_modal_owner, [:cmd, :prompt_cancelled, prompt_payload]],
          [:terminal, :pop_modal]
        ]
      when :accept_line
        text = @field.buffer.text.to_s
        @field.accept_line
        [
          [:terminal, :send_modal_owner, [:cmd, :prompt_result, { kind: @kind, text: text }]],
          [:terminal, :pop_modal]
        ]
      when :interrupt_if_empty
        if @field.buffer.text.to_s.empty?
          [
            [:terminal, :send_modal_owner, [:cmd, :prompt_cancelled, prompt_payload]],
            [:terminal, :pop_modal]
          ]
        else
          @field.act_on(action, *args, env: env)
          []
        end
      else
        @field.act_on(action, *args, env: env)
        []
      end
    rescue ActionError => e
      FatTerm.error("PromptSession#handle_action: ActionError #{e.message}", tag: :session)
      []
    end

    def close
      if @win
        @win.erase
        @win.noutrefresh if @win.respond_to?(:noutrefresh)
        @win.close
        @win = nil
      end
      nil
    end

    def popup_geometry(cols:, rows:)
      max_w = [cols - (PROMPT_POPUP_MARGIN * 2), PROMPT_POPUP_MIN_WIDTH].max
      max_h = [rows - (PROMPT_POPUP_MARGIN * 2), 5].max

      preferred_w = (cols * 2 / 3).floor
      preferred_w = 50 if preferred_w < 50

      message_width = @message.to_s.length
      prompt_width = @field.prompt_text.to_s.length + @field.buffer.text.to_s.length
      content_width = [message_width, prompt_width].max + 4

      width = [preferred_w, content_width].max
      width = [width, max_w].min
      width = [width, PROMPT_POPUP_MAX_WIDTH].min

      extra_rows = 2
      extra_rows += 1 if @message && !@message.empty?
      extra_rows += 1

      height = [extra_rows, max_h].min

      [width, height]
    end

    private

    def rebuild_windows!(terminal)
      if @win
        @win.erase
        @win.noutrefresh if @win.respond_to?(:noutrefresh)
        @win.close
      end

      cols = ::Curses.cols
      rows = ::Curses.lines
      width, height = popup_geometry(cols: cols, rows: rows)
      x = (cols - width) / 2
      y = (rows - height) / 2
      @win = ::Curses::Window.new(height, width, y, x)
    end

    def prompt_payload
      {
        kind: @kind,
        text: @field.buffer.text.to_s,
      }
    end

    def action_env(terminal:, event:)
      ActionEnvironment.new(
        session: self,
        terminal: terminal,
        counter: counter,
        event: event,
        field: @field,
        buffer: @field.buffer,
      )
    end
  end
end
