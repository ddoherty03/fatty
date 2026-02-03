# frozen_string_literal: true

module FatTerm
  class View
    attr_reader :id, :z

    def initialize(id: nil, z: 0, log: false)
      @id = (id || self.class.name.split("::").last).to_s
      @z  = Integer(z)
      @log = !!log
    end

    # Render wrapper: logs once, then delegates to #draw.
    # Subclasses implement #draw.
    def render(screen:, renderer:, terminal:, session:)
      if @log
        FatTerm.log(
          "View.render",
          tag: :render,
          view: id,
          z: z,
          session: session.respond_to?(:id) ? session.id : session.class.name,
        )
      end

      draw(screen:, renderer:, terminal:, session:)
    end

    def draw(screen:, renderer:, terminal:, session:)
      raise NotImplementedError, "#{self.class} must implement #draw"
    end
  end
end
