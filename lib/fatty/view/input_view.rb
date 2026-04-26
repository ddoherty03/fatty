# frozen_string_literal: true

module Fatty
  class InputView < Fatty::View
    def draw(screen:, renderer:, terminal:, session:)
      renderer.render_input_field(session.field)
    end
  end
end
