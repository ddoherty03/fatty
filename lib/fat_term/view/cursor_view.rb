# frozen_string_literal: true

module FatTerm
  class CursorView < FatTerm::View
    def draw(screen:, renderer:, terminal:, session:)
      renderer.restore_cursor(session.field)
    end
  end
end
