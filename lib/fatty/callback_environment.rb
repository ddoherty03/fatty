# frozen_string_literal: true
#
# This class provides a wrapper around components that can be handed off to
# Terminal's on_accept method (or other callbacks) for access to Fatty's
# facilities.  The on_accept proc will receive two parameters: (1) the edited
# line and (2) an instance of this class called `env` from which the user can
# access certain facilities that Fatty provides.
#
# For example, by using env.append("some text"), the given text will be
# displayed in the output pane with scrolling, search, etc.  A related method,
# `env.markdown(<markdown_text>)` will render the given text as markdown and
# then append it to the output pane.
#
# Using env.status will display text in the status area.  Likewise with
# env.alert for the alert panel.
#
# You can add a Progress object to the status_area with env.add_progress and
# update it with `env.progress.update`.
module Fatty
  class CallbackEnvironment
    include OutputApi
    include MenuApi
    include ProgressApi
    include PromptApi
    include StatusApi
    include AlertApi

    attr_reader :progress, :commands

    def initialize(terminal:, output_id: nil)
      @terminal = terminal
      @output_id = output_id
      @progress = nil
      @commands = []
    end

    def queue(command)
      @commands << command
      command
    end

    private

    attr_reader :terminal, :output_id
  end
end
