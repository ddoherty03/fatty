# frozen_string_literal: true

module Fatty
  class ISearchSession < Session
    action_on :session

    attr_reader :field, :direction

    def id = :isearch

    DEFAULT_ISEARCH_HISTORY_FILE = File.expand_path("~/.fatty_search_history")
    DEFAULT_ISEARCH_HISTORY_MAX  = 200

    def initialize(direction: :forward, last_pattern: nil, history: nil)
      super(keymap: Keymaps.emacs, views: [])

      @direction = direction.to_sym
      @failed = false
      @last_text = nil
      @last_pattern = last_pattern.to_s

      @field = Fatty::InputField.new(
        prompt: Prompt.new { isearch_prompt },
        history: history,
        history_kind: :search_string,
        # ? history_ctx: -> { { session: "pager_isearch" } },
      )
    end

    #########################################################################################
    # Framework and Session Hooks
    #########################################################################################

    def keymap_contexts
      [:isearch, :text, :terminal]
    end

    def view(screen:, renderer:)
      row = screen.output_rect.rows - 1

      ::Curses.curs_set(1)
      renderer.render_pager_field(@field, row: row, role: :search_input)
      renderer.restore_output_cursor(@field, row: row)
    end

    def interrupt
      cancel!
    end

    ############################################################################################
    # Actions
    ############################################################################################

    desc "Return the line so far as the search string"
    action :isearch_accept do
      accept!
    end

    desc "Quit the I-Search session"
    action :isearch_cancel do
      cancel!
    end

    desc "Move to the next matching text"
    action :isearch_next do
      step_next!
    end

    desc "Move to the prior matching text"
    action :isearch_prev do
      step_prev!
    end

    private

    def update_cmd(name, payload)
      cmds = []
      case name
      when :isearch_set_failed
        @failed = !!payload[:failed]
        @field.prompt = isearch_prompt
      end
      cmds
    end

    def action_env(event:)
      ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
      )
    end

    def handle_action(action, args, event:)
      env = action_env(event: event)

      if Fatty::Actions.lookup(action)&.fetch(:on) == :session
        Fatty::Actions.call(action, env, *args)
      else
        @field.act_on(action, *args, env: env)
        maybe_preview!
      end
    rescue Fatty::ActionError
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
