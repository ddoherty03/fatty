# frozen_string_literal: true

module Fatty
  class StatusView < View
    def render(screen:, renderer:, terminal:)
      return unless terminal.status_text

      renderer.render_status(
        terminal.status_text,
        role: terminal.status_role || :status_info,
      )
    end
  end
end
