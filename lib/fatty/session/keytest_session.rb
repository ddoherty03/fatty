# frozen_string_literal: true

require "tmpdir"

module Fatty
  class KeyTestSession < Session
    attr_reader :output_session

    def initialize(output_dir: Dir.tmpdir)
      super(id: :keytest, keymap: nil)
      @output_session = OutputSession.new
      @path = nil
      @suggestions = []
    end

    #########################################################################################
    # Session Protocol
    #########################################################################################

    def init(terminal:)
      commands = super
      @suggestions = []

      commands.concat(output_session.init(terminal: terminal))
      commands << Command.terminal(:register_session, session: output_session)
      commands << Command.session(output_session.id, :resize)
      commands << Command.session(output_session.id, :set_mode, mode: :scrolling)
      commands << Command.session(output_session.id, :begin_command)
      commands << Command.session(
        output_session.id,
        :append,
        text: <<~TEXT,
          Key test mode

          Press keys to inspect Fatty's decoding and binding resolution.
          Press q, ESC, or C-g to leave key test mode.

        TEXT
        follow: true,
      )
      commands << show_quit_status_command
      commands
    end

    def update(command)
      log_update(command)
      commands =
        case command.action
        when :key
          ev = command.payload.fetch(:event)
          if quit_key?(ev)
            write_suggestions_commands + [
              Command.session(output_session.id, :append, text: "Leaving key test mode.\n\n", follow: true),
              Command.session(:status, :clear),
              Command.terminal(:pop_modal),
              Command.session(
                :status,
                :show,
                text: "KeyTest suggestions written to #{@path}",
                role: :good,
              ),
            ]
          else
            snippet = ev.suggested_snippet(terminal_name)
            @suggestions << snippet unless snippet.empty?
            text = [
              ev.report,
              "\nSuggested keybindings:\n",
              snippet,
              "\n",
            ].join
            [
              Command.session(
                output_session.id,
                :append,
                text: text,
                follow: true,
                mode: :scrolling),
              show_quit_status_command,
            ]
          end
        else
          []
        end
      Array(commands)
    end

    def view
      output_session.view
    end

    def close
      output_session.close
      nil
    end

    private

    # simplecov:disable

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

    def show_quit_status_command
      Command.session(
        :status,
        :show,
        text: "KeyTest — press q, ESC, or C-g to quit  (TERM: #{terminal_name})",
        role: :warn,
      )
    end

    def write_suggestions_commands
      suggestions = @suggestions.uniq
      return [] if suggestions.empty?

      @path = File.join(
        Dir.tmpdir,
        "fatty-keytest-#{Time.now.strftime('%Y%m%d-%H%M%S')}.yml",
      )
      File.write(@path, suggestion_file_text(suggestions))
      [
        Command.session(
          output_session.id,
          :append,
          text: <<~TEXT,
            =======================================================
            KeyTest suggestions written to:
            #{@path}

          TEXT
          follow: true,
          mode: :scrolling,
        ),
      ]
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

         - mouse: <BUTTONNAME>
           context: paging
           action: page_up

        Where <BUTTONNAME> is one of:
          scroll_up
          scroll_down
          left_pressed,
          left_released,
          left_clicked,
          left_double_clicked,
          left_triple_clicked,
          middle_pressed,
          middle_released,
          middle_clicked,
          middle_double_clicked,
          middle_triple_clicked,
          right_pressed,
          right_released,
          right_clicked,
          right_double_clicked,
          right_triple_clicked

        All of which may also be combined with modifiers: ctrl, meta, and shift.

      TEXT
      out << "\n"
      out << suggestions.join("\n\n")
      out << "\n"
      out
    end
  end
end
