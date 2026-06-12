# frozen_string_literal: true

module Fatty
  ###########################################################################################
  # Public API convenience methods for use by the library user
  ###########################################################################################
  module AlertApi
    # Display text in the status area with the given "role", which determines
    # the coloring of the displayed text via themeing.
    def alert(text, level: :info)
      terminal.apply_command(
        Command.session(:alert, :show, text: text, level: level)
      )
      nil
    end
  end
end
