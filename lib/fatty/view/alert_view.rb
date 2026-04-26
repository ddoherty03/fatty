# frozen_string_literal: true

module FatTerm
  class AlertView < FatTerm::View
    def initialize(id: "alert", z: 1_000, log: false)
      super(id: id, z: z, log: log)
    end

    def draw(screen:, renderer:, terminal:, session:)
      # session is AlertSession; it owns `current`
      renderer.render_alert(session.current)
    end
  end
end
