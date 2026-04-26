# frozen_string_literal: true

module Fatty
  class MenuEnv
    attr_reader :terminal, :session, :label, :payload

    def initialize(terminal:, session:, label: '', payload: nil)
      @terminal = terminal
      @session = session
      @label = label
      @payload = payload
    end

    def output(text)
      session.output.append(text.to_s)
    end

    def status(text)
      terminal.set_status(text.to_s)
    end
  end
end
