# frozen_string_literal: true

require "tmpdir"

module Fatty
  class KeyTestSession < Session
    def id = :keytest

    def initialize(owner: nil)
      super(keymap: nil, views: [])
      @owner = owner
    end

    def init(terminal:)
      super
      @suggestions = []
      @owner ||= terminal.focused_session
      show_quit_status
      force_scrolling_output!
      append <<~TEXT
        Key test mode

        Press keys to inspect Fatty's decoding and binding resolution.
        Press q, ESC, or C-g to leave key test mode.

      TEXT
      []
    end

    def update_key(ev)
      if quit_key?(ev)
        append "Leaving key test mode.\n\n"
        return [[:terminal, :pop_modal]]
      end

      # append "  TERM:      #{terminal_name}\n"
      append ev.report
      snippet = ev.suggested_snippet(terminal_name)
      append snippet + "\n"
      @suggestions << snippet unless snippet.empty?
      show_quit_status
      []
    end

    def view(screen:, renderer:)
      # Intentionally blank. The underlying shell session renders the output
      # pane; this modal only captures keys and appends diagnostic text.
      nil
    end

    def close
      write_suggestions!
      restore_owner_pager!
      terminal.clear_status if terminal.respond_to?(:clear_status)
      nil
    end

    private

    def append(text)
      return unless @owner && @owner.respond_to?(:append_output)

      force_scrolling_output!

      before = @owner.output.lines.length
      @owner.append_output(text.to_s, follow: false)

      height = @owner.viewport.height.to_i
      added = @owner.output.lines.length - before

      if added >= height
        @owner.viewport.top = before
        @owner.viewport.clamp!(@owner.output.lines)
      else
        @owner.viewport.page_bottom(@owner.output.lines)
      end

      terminal.renderer.reset_frame_cache if terminal.respond_to?(:renderer)
    end

    def force_scrolling_output!
      if @owner && @owner.respond_to?(:pager)
        @owner.pager.paging_to_scrolling
      end
    end

    def quit_key?(ev)
      ev.key == :q ||
        ev.key == :escape ||
        (ev.key == :g && ev.ctrl?)
    end

    def terminal_name
      env =
        if terminal.respond_to?(:env)
          terminal.env
        else
          terminal.instance_variable_get(:@env)
        end

      env && env[:terminal] || ENV.fetch("TERM", "unknown")
    end

    def show_quit_status
      terminal.warn("KeyTest — press q, ESC, or C-g to quit  (TERM: #{terminal_name})")
    end

    def write_suggestions!
      suggestions = @suggestions.uniq
      return if suggestions.empty?

      path = File.join(Dir.tmpdir, "fatty-keytest-#{Time.now.strftime('%Y%m%d-%H%M%S')}.yml")

      File.write(path, suggestion_file_text(suggestions))

      append <<~TEXT
        =======================================================
        KeyTest suggestions written to:
        #{path}

      TEXT

      terminal.good("KeyTest suggestions written to #{path}")
    end

    def suggestion_file_text(suggestions)
      out = <<~TEXT
        # Fatty keytest suggestions
        # Generated at #{Time.now}

        KEYNAMES

        Known/common key names for keydefs.yml/keybindings.yml:
      TEXT

      Fatty::Curses.valid_keynames.each do |name|
        out << "   #{name}\n"
      end

      out << <<~TEXT

        Printable keys are also valid key names, for example:
          a
          y
          ]
          /
        Use ctrl/meta/shift flags in keybindings.yml for modifiers.

        NOTE: You can also define additional key names in keydefs.yml.
        For example: if your terminal reports code 652 for the Pause key:

         terminal:
           tmux:
             map:
               652:
                 key: pause

         Then you can bind it to an action in keybindings.yml:

         - key: pause
           action: your_action

        ACTIONS

        Valid action names for keybindings.yml:

        NOTE: Fatty also supports user-defined actions. The extension mechanism is still
        evolving; see README.md for the current plugin/action registration details.
      TEXT

      Fatty::Actions.catalog_by_target.each do |target, names|
        out << "\n"
        out << "#{target} actions:\n"

        names.each do |name|
          out << "   #{name}\n"
        end
      end

      out << <<~TEXT

        CONTEXTS

        Valid contexts for keybindings.yml:\n
      TEXT

      Fatty::KeyMap.valid_contexts.each do |name|
        out << "    #{name}\n"
      end

      out << <<~TEXT
        If context is omitted, the default is #{Fatty::KeyMap::DEFAULT_CONTEXT}.

        MOUSE EVENTS

        Mouse events may also be bound in keybindings.yml, for example:

        - mouse: scroll_up
          context: paging
          action: page_up

        - mouse: scroll_down
          context: paging
          action: page_down
      TEXT
      out << "\n"
      out << suggestions.join("\n\n")
      out << "\n"
      out
    end

    def restore_owner_pager!
      if @owner&.respond_to?(:pager)
        @owner.pager.quit_paging
      end
    end
  end
end
