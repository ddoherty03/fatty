# frozen_string_literal: true

module FatTerm
  class OutputView < View
    def draw(screen:, renderer:, terminal:, session:)
      renderer.render_output(session.output, viewport: session.viewport)
    end
  end
end
