# frozen_string_literal: true

module Fatty
  class SearchSession < Session
    attr_reader :field, :direction, :regex

    DEFAULT_SEARCH_HISTORY_FILE = File.expand_path("~/.fatty_search_history")
    DEFAULT_SEARCH_HISTORY_MAX  = 200

    def initialize(direction: :backward, regex: false, history: nil, prefix: nil)
      super(keymap: Keymaps.emacs, views: [])

      @direction = direction.to_sym
      @regex = !!regex

      prompt = search_prompt(direction: @direction, regex: @regex)

      @field = Fatty::InputField.new(
        prompt: prompt,
        history: history,
        history_kind: -> { @regex ? :search_regex : :search_string },
      )
      text = prefix.to_s
      @field.buffer.replace(text) unless text.empty?
    end

    def keymap_contexts
      [:search, :input, :terminal]
    end

    def handle_action(action, args, event:)
      env = ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
      )

      case action.to_sym
      when :accept_line
        accept_search
      when :popup_cancel, :interrupt
        [[:terminal, :pop_modal]]
      when :search_toggle_regex
        toggle_regex
      when :search_step_forward
        step_search(:forward)
      when :search_step_backward
        step_search(:backward)
      else
        @field.act_on(action, *args, env: env)
        []
      end
    rescue Fatty::ActionError
      []
    end

    def view(screen:, renderer:)
      row = screen.output_rect.rows - 1

      ::Curses.curs_set(1)
      renderer.render_pager_field(
        @field,
        row: row,
        role: :search,
      )
      renderer.restore_output_cursor(@field, row: row)
    end

    def toggle_regex
      @regex = !@regex
      @field.prompt = search_prompt(direction: @direction, regex: @regex)
      []
    end

    private

    def search_prompt(direction:, regex:)
      label =
        if regex
          "Regex: "
        else
          "Search string: "
        end

      # If you want a subtle direction hint right at the prompt:
      dir = (direction == :backward ? "↑ " : "↓ ")
      dir + label
    end

    def accept_search
      pattern = @field.accept_line.to_s

      cmds = []
      cmds << [
        :terminal,
        :send_modal_owner,
        [:cmd, :pager_search_set, { pattern: pattern, direction: direction, regex: regex }]
      ]
      cmds << [:terminal, :pop_modal]
      cmds
    end

    def step_search(dir)
      [[:terminal, :send_modal_owner, [:cmd, :pager_search_step, { direction: dir }]]]
    end
  end
end
