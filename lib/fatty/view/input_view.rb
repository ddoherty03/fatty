# frozen_string_literal: true

module FatTerm
  class InputView < FatTerm::View
    def draw(screen:, renderer:, terminal:, session:)
      renderer.render_input_field(session.field)
    end
  end
end
