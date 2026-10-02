# frozen_string_literal: true

module Fatty
  module Help
    CONTEXT_DESCRIPTIONS = {
      text: "The text context supplies the shared editing keys for moving the cursor, " \
        "deleting text, undoing edits, and copying or pasting. It is active while editing " \
        "the command line, prompts, search queries, and popup filters. The input context " \
        "below adds command-line-specific keys; other text fields add their own context. " \
        "Those more specific bindings take precedence over text bindings.",
      input: "The input context is active while you compose a command at the main prompt. " \
        "It adds command history, completion, and submission to the shared text editing " \
        "keys above. Fatty checks input bindings first, then text, then terminal. " \
        "These input bindings do not apply to other prompts or search fields, or while paging output.",
      terminal: "The terminal context supplies shared controls available from command input, " \
        "the pager, prompts, searches, and popups. It is checked after the other active " \
        "contexts, so these keys work throughout the normal interface unless a more " \
        "specific context binds the same key. Special modes such as key testing handle " \
        "keys separately.",
      paging: "The paging context is active while you browse output, including this help. " \
        "Its keys scroll, jump, search, narrow the displayed lines, or leave the pager. " \
        "Printable keys act as pager commands rather than editing the command line. " \
        "Terminal bindings remain available when paging does not bind the same key.",
      popup: "The popup context is active in menus and selection lists. Its keys move " \
        "among items, accept a choice, or cancel. Text bindings edit the popup's filter, " \
        "while popup bindings take precedence for navigation and selection. Terminal " \
        "bindings are checked last.",
      popup_multi: "The popup_multi context adds selection controls to popups that let " \
        "you choose multiple items. Its bindings are checked before popup, text, and " \
        "terminal bindings. By default, Space toggles the current item instead of " \
        "inserting a space into the filter.",
      prompt: "The prompt context is active when Fatty asks you to enter an answer in " \
        "a prompt. It supplies acceptance, cancellation, and prompt-history controls. " \
        "The shared text bindings edit your answer; terminal bindings are checked last. " \
        "The main command line uses input instead of this context.",
      search: "The search context is active while you enter a pager search query. It " \
        "provides search history, acceptance and cancellation, match navigation, and " \
        "switching between literal text and regular expressions. Text bindings edit " \
        "the query, and terminal bindings are checked last. After leaving the search " \
        "field, paging bindings control the output again.",
      isearch: "The isearch context is active during incremental pager search, where " \
        "the match updates as you type. Its keys step through matches, recall search " \
        "history, accept the search, or cancel and restore the earlier view. Text " \
        "bindings edit the query, and terminal bindings are checked last.",
    }.freeze
    private_constant :CONTEXT_DESCRIPTIONS

    def self.path
      File.expand_path("../../help/help.md", __dir__)
    end

    def self.text
      File.read(path)
    end

    def self.keybindings(keymap, width: 83)
      lines = ["# Current keybindings", "",
               "Fatty is the terminal user-interface library used by this application. " \
                 "It provides command-line editing, output paging and search, and interactive prompts and menus.", "",
               "Use the pager to browse or search; quit paging to return.", "",
               "The tables below show the loaded keybindings for each context, including user overrides. " \
                 "Keys use Emacs-like notation: C- means hold Control, M- means hold Alt (also called Meta), " \
                 "and C-M- means hold both. Shift may be indicated by the final key name, as in M-R, " \
                 "or by an explicit S- prefix, as in M-S-r. Both examples mean Alt-Shift-R. " \
                 "Printable characters insert text in text-entry contexts.", "",
               "The Action column gives the name of the Fatty action bound to each key. " \
                 "These names are useful when customizing keybindings or working on Fatty itself."]
      key_width, action_width, description_width = keybinding_column_widths(width)
      keymap.bindings.sort_by { |context, _| [[:text, :input].index(context) || 2, context.to_s] }.each do |context, bindings|
        description = CONTEXT_DESCRIPTIONS.fetch(context) do
          "This context is supplied by the application or a custom keymap. Its bindings " \
            "apply when the application activates it; the application determines how " \
            "it combines with other contexts."
        end
        lines << "" << "## In the #{context} context:" << "" << description << ""
        lines << "| Key | Action | Description |" << "| --- | --- | --- |"
        entries = bindings.map do |gesture, binding|
          key = gesture.is_a?(MouseGesture) ? gesture.button : gesture.key
          label = KeyEvent.key_to_str(key: key, ctrl: gesture.ctrl, meta: gesture.meta, shift: gesture.shift)
          action, *args = Array(binding)
          description = Actions.lookup(action)&.fetch(:doc)
          action_text = ([action] + args.map(&:inspect)).join(" ")
          [label, action_text, description]
        end
        entries.sort_by(&:first).each do |label, action, description|
          keys = wrap_cell(label, key_width)
          actions = wrap_cell(action, action_width)
          descriptions = wrap_cell(description, description_width)
          [keys.length, actions.length, descriptions.length].max.times do |index|
            lines << "| #{escape_cell(keys[index])} | #{escape_cell(actions[index])} | #{escape_cell(descriptions[index])} |"
          end
        end
      end
      lines.join("\n")
    end

    def self.keybinding_column_widths(width)
      width = [width, 83].min
      key_width = [[width / 6, 12].min, 3].max
      action_width = [[width - 12 - key_width - 11, 27].min, 6].max
      [key_width, action_width, [width - 12 - key_width - action_width, 11].max]
    end

    def self.wrap_cell(text, width)
      lines = []
      line = +""
      text.to_s.split.each do |word|
        if !line.empty? && line.length + word.length + 1 > width
          lines << line
          line = +""
        end
        while word.length > width
          lines << word.slice!(0, width)
        end
        line << " " unless line.empty?
        line << word
      end
      lines << line unless line.empty?
      lines
    end
    private_class_method :wrap_cell

    def self.escape_cell(text)
      # Entities keep punctuation keys (especially pipes) inside their cells.
      text.to_s.each_char.map { |char| char.match?(/[[:alnum:] ]/) ? char : "&##{char.ord};" }.join
    end
    private_class_method :escape_cell
  end
end
