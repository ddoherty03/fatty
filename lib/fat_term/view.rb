# frozen_string_literal: true

module FatTerm
  # Base class for pure-ish renderers.
  #
  # Views should:
  # - read session state (and/or other model objects)
  # - draw via Screen/Renderer (curses writes)
  # - avoid mutating session state
  #
  # The runtime decides when to call views; a view can optionally advertise a
  # z-index for layering.
  class View
    attr_reader :id
    attr_reader :z

    def initialize(id: nil, z: 0)
      @id = id || self.class.name.split("::").last
      @z = Integer(z)
    end

    # Render the view.
    #
    # Arguments intentionally mirror our current world (Terminal + Renderer),
    # but are keyworded to make future evolution non-breaking.
    def render(screen:, renderer:, terminal:, session:)
      FatTerm::Logger.log(:view, tag: :render, screen: screen, terminal: terminal, session: session)
    end
  end
end
