# frozen_string_literal: true

# This class provides a wrapper around components that can be handed off to
# Terminal's on_accept method for access to the terminal, the session, and a
# Progress widget.
module Fatty
  class AcceptEnv
    attr_reader :session

    def initialize(session:)
      @session = session
      @progress = nil
    end

    def terminal
      session.terminal
    end

    def progress(**opts)
      @progress ||= Fatty::Terminal::Progress.new(terminal: terminal, **opts)
    end
  end
end
