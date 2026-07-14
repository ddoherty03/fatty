# frozen_string_literal: true

module Fatty
  ###########################################################################################
  # Public API convenience methods for use by the library user
  ###########################################################################################
  module StatusApi
    # Display text in the status area with the given "role", which determines
    # the coloring of the displayed text via themeing.
    def status(text, role: :info, replace: false, render: true)
      terminal.apply_command(
        Command.session(
          :status,
          :show,
          text: text,
          role: role,
          append: !replace,
        )
      )
      terminal.without_cursor_restore do
        terminal.render_frame
      end if render
      nil
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "good," i.e., success.
    def good(text, replace: false, render: true)
      status(text, role: :good, replace:, render:)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "info".
    def info(text, replace: false, render: true)
      status(text, role: :info, replace:, render:)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "warn," i.e., short of an error but not complete
    # success either.
    def warn(text, replace: false, render: true)
      status(text, role: :warn, replace:, render:)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "oops," i.e., a soft failure.
    def error(text, replace: false, render: true)
      status(text, role: :error, replace:, render:)
    end

    def oops(text, replace: false, render: true)
      status(text, role: :error, replace:, render:)
    end
  end
end
