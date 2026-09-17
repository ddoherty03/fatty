# frozen_string_literal: true

module Fatty
  module SuspendApi
    def suspend(&block)
      terminal.suspend(&block)
    end
  end
end
