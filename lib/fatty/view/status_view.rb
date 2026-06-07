# frozen_string_literal: true

module Fatty
  class StatusView < View
    def draw(renderer:, terminal:, session:)
      return unless session.visible?

      renderer.render_status(
        session.text,
        role: session.role || :info,
      )
    end
  end
end
