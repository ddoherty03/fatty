# frozen_string_literal: true

module Fatty
  ###########################################################################################
  # Public API convenience methods for use by the library user
  ###########################################################################################
  module StatusApi
    # Display text in the status area with the given "role", which determines
    # the coloring of the displayed text via themeing.
    def status(text, role: :info)
      cmd = Fatty::Command.session(:status, :show, text: text.to_s, role: role)
      apply_command(cmd)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "info".
    def info(text)
      status(text, role: :info)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "good," i.e., success.
    def good(text)
      status(text, role: :good)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "warn," i.e., short of an error but not complete
    # success either.
    def warn(text)
      status(text, role: :warn)
    end

    # Display a message to the user in the status line, colored according to
    # the Config for "oops," i.e., a soft failure.
    def oops(text)
      status(text, role: :error)
    end
  end
end
