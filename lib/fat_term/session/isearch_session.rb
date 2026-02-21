# frozen_string_literal: true

module FatTerm
  class ISearchSession < Session
    attr_reader :field, :direction

    DEFAULT_ISEARCH_HISTORY_FILE = File.expand_path("~/.fat_term_search_history")
    DEFAULT_ISEARCH_HISTORY_MAX  = 200

    def initialize(direction: :forward, history_path: nil, history_max: nil)
      super(keymap: Keymaps.emacs, views: [])

      @direction = direction.to_sym
      @last_text = nil

      history = FatTerm::History.new(
        path: history_path || DEFAULT_ISEARCH_HISTORY_FILE,
        max: history_max || DEFAULT_ISEARCH_HISTORY_MAX,
      )

      @field = FatTerm::InputField.new(prompt: isearch_prompt, history: history)
    end

    def keymap_contexts
      [:isearch, :input, :terminal]
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
      else
        @field.act_on(action, *args, env: env)
        cmds.concat(maybe_preview!)
      end

      cmds
    rescue FatTerm::ActionError
      []
    end

    def view(screen:, renderer:, terminal:)
      row = screen.output_rect.rows - 1

      ::Curses.curs_set(1)
      renderer.render_pager_field(@field, row: row, role: :search)
      renderer.restore_output_cursor(@field, row: row)
    end

    private

    def isearch_prompt
      "I-search: "
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
      # Step forward in the original direction while staying in preview mode.
      [[:terminal, :send_modal_owner, [:cmd, :pager_isearch_step, { direction: @direction }]]]
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
