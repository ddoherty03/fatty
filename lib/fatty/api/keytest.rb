module Fatty
  module KeytestApi
    def keytest
      [
        Command.terminal(:push_modal, session: Fatty::KeyTestSession.new),
        Command.session(:alert, :clear),
      ]
    end
  end
end
