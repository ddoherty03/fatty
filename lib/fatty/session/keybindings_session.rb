# frozen_string_literal: true

module Fatty
  class KeybindingsSession < OutputSession
    def init(terminal:)
      super
      width = [screen.output_rect.cols, 83].min
      text = Markdown.render(
        Help.keybindings(keymap, width: width),
        width: [width, 80].min,
        table_widths: Help.keybinding_column_widths(width),
        table_borders: true,
      )
      # Keep Markdown roles semantic so theme changes recolor existing help.
      sections = text.lines.chunk { |line| help_role(line.chomp) }
      [
        Command.session(id, :resize),
        *sections.map { |role, lines| Command.session(id, :append, text: lines.join, role: role, follow: false) },
        Command.session(id, :set_mode, mode: :paging),
      ]
    end

    def update(command)
      return [Command.terminal(:pop_modal)] if command.action == :quit_paging

      super
    end

    def handle_resize
      [Command.session(id, :resize)]
    end

    def show_keybindings
      []
    end

    private

    def help_role(line)
      if line == "Current keybindings"
        :markdown_h1
      elsif keymap.contexts.any? { |context| line == "In the #{context} context:" }
        :markdown_h2
      elsif line.start_with?("  │ Key ")
        :markdown_table_header
      else
        :output
      end
    end

    def keymap_contexts
      [:paging, :terminal]
    end

    def apply_action(action, args, event:)
      return [Command.terminal(:pop_modal)] if action == :quit_paging

      super
    end
  end
end
