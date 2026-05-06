# frozen_string_literal: true

module Fatty
  class SearchSession < Session
    action_on :session

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

    #########################################################################################
    # Framework and Session Hooks
    #########################################################################################

    def keymap_contexts
      [:search, :text, :terminal]
    end

    def view(screen:, renderer:)
      row = screen.output_rect.rows - 1

      ::Curses.curs_set(1)
      renderer.render_pager_field(
        @field,
        row: row,
        role: :search_input,
      )
      renderer.restore_output_cursor(@field, row: row)
    end

    ############################################################################################
    # Actions
    ############################################################################################

    desc "Return the line so far as the prompt input"
    action :search_accept do
      search_accept
    end

    desc "End the search session"
    action :search_cancel do
      cancel!
    end

    desc "Toggle between string i-search and regex search"
    action :search_toggle_regex do
      toggle_regex
    end

    desc "Move to the next search match"
    action :search_step_forward do
      step_search(:forward)
    end

    desc "Move to the prior search match"
    action :search_step_backward do
      step_search(:backward)
    end

    def handle_action(action, args, event:)
      env = ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
      )

      if Fatty::Actions.lookup(action)&.fetch(:on) == :session
        Fatty::Actions.call(action, env, *args)
      else
        @field.act_on(action, *args, env: env)
      end
    rescue Fatty::ActionError
      []
    end

    def toggle_regex
      @regex = !@regex
      @field.prompt = search_prompt(direction: @direction, regex: @regex)
      []
    end

    def cancel!
      [[:terminal, :pop_modal]]
    end

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

    def search_accept
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
