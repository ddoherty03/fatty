# frozen_string_literal: true

module FatTerm
  class ISearchSession < Session
    attr_reader :field, :direction

    def id = :isearch

    DEFAULT_ISEARCH_HISTORY_FILE = File.expand_path("~/.fat_term_search_history")
    DEFAULT_ISEARCH_HISTORY_MAX  = 200

    def initialize(direction: :forward, last_pattern: nil, history: nil)
      super(keymap: Keymaps.emacs, views: [])

      @direction = direction.to_sym
      @failed = false
      @last_text = nil
      @last_pattern = last_pattern.to_s

      @field = FatTerm::InputField.new(
        prompt: Prompt.new { isearch_prompt },
        history: history,
        history_kind: :search_string,
        # ? history_ctx: -> { { session: "pager_isearch" } },
      )
    end

    def keymap_contexts
      [:isearch, :input, :terminal]
    end

    def view(screen:, renderer:, terminal:)
      row = screen.output_rect.rows - 1

      ::Curses.curs_set(1)
      renderer.render_pager_field(@field, row: row, role: :search)
      renderer.restore_output_cursor(@field, row: row)
    end

    private

    def update_cmd(name, payload, terminal:)
      cmds = []
      case name
      when :isearch_set_failed
        @failed = !!payload[:failed]
        @field.prompt = isearch_prompt
      end
      cmds
    end

    def handle_action(action, args, terminal:, event:)
      env = ActionEnvironment.new(
        session: self,
        terminal: terminal,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
      )

      cmds = []
      case action.to_sym
      when :accept_line
        cmds.concat(accept!)
      when :popup_cancel, :interrupt
        cmds.concat(cancel!)
      when :isearch_next
        cmds.concat(step_next!)
      when :isearch_prev
        cmds.concat(step_prev!)
      else
        @field.act_on(action, *args, env: env)
        cmds.concat(maybe_preview!)
      end

      cmds
    rescue FatTerm::ActionError
      []
    end

    def isearch_prompt
      base = @failed ? "Failing I-search: " : "I-search: "
      arrow = @direction == :backward ? "↑ " : "↓ "
      arrow + base
    end

    def accept!
      pattern = @field.accept_line.to_s
      cmds = []
      cmds << [:terminal, :send_modal_owner, [:cmd, :pager_isearch_commit, { pattern: pattern, direction: @direction }]]
      cmds << [:terminal, :pop_modal]
      cmds
    end

    def cancel!
      [[:terminal, :send_modal_owner, [:cmd, :pager_isearch_cancel, {}]], [:terminal, :pop_modal]]
    end

    def step_next!
      @direction = :forward
      cmds = []
      cmds.concat(prefill_last_pattern_if_empty!)
      cmds << [:terminal, :send_modal_owner, [:cmd, :pager_isearch_step, { direction: @direction }]]
      cmds
    end

    def step_prev!
      @direction = :backward
      cmds = []
      cmds.concat(prefill_last_pattern_if_empty!)
      cmds << [:terminal, :send_modal_owner, [:cmd, :pager_isearch_step, { direction: @direction }]]
      cmds
    end

    def prefill_last_pattern_if_empty!
      current = @field.buffer.text.to_s
      pat = @last_pattern.to_s
      return [] unless current.empty?
      return [] if pat.strip.empty?

      env = ActionEnvironment.new(
        session: self,
        terminal: nil,
        counter: counter,
        event: nil,
        buffer: @field.buffer,
        field: @field,
      )

      # Replace buffer contents with the last pattern, then preview immediately.
      @field.act_on(:replace, pat, env: env)
      maybe_preview!
    end

    def maybe_preview!
      text = @field.buffer.text.to_s
      return [] if @last_text == text

      @last_text = text.dup
      [
        [
          :terminal,
          :send_modal_owner,
          [:cmd, :pager_isearch_update, { pattern: text, direction: @direction }],
        ]
      ]
    end
  end
end
