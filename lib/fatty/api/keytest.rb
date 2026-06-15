# frozen_string_literal: true

module Fatty
  module KeytestApi
    def keytest
      queue(Command.terminal(:push_modal, session: Fatty::KeyTestSession.new))
      queue(Command.session(:alert, :clear))
      nil
    end
  end
end
