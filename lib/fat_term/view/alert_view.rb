# frozen_string_literal: true

module FatTerm
  module Views
    # AlertView renders the AlertPanel as a bottom-line overlay.
    #
    # It is deliberately "dumb": it reads the panel state and delegates all
    # drawing to the injected renderer.
    class AlertView < View
      def initialize(panel:, id: "alert", z: 1_000)
        super(id:, z:)
        @panel = panel
      end

      def render(screen:, renderer:, terminal:, session:)
        return unless @panel.visible?

        alert = @panel.current
        renderer.render_alert(alert)
      end
    end
  end
end
