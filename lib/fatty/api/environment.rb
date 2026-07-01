# frozen_string_literal: true

module Fatty
  module EnvironmentApi
    def environment
      h = Fatty::Env.detect
      h[:truecolor_enabled] = terminal.ctx.truecolor_enabled?
      h[:curses] = terminal.ctx.environment if terminal.ctx
      h
    end
  end
end
