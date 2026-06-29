# frozen_string_literal: true

module Fatty
  module EnvironmentApi
    def environment
      h = Fatty::Env.detect
      h[:curses] = terminal.ctx.environment if terminal.ctx
      h
    end
  end
end
