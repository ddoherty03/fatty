# frozen_string_literal: true

module FatTerm
  # Base class for stateful runtime components.
  #
  # Charm/Bubbletea-style contract:
  #
  #   init(terminal:)               => [self, commands]
  #   update(message, terminal:)    => [self, commands]
  #   view(screen:, renderer:, terminal:) => renders only (no return contract)
  #
  # Where `commands` is an Array (possibly empty). Terminal is responsible for
  # executing commands after each update cycle.
  class Session
    attr_reader :views

    def initialize(views: [])
      @views = Array(views)
    end

    # Called once when the session becomes active (e.g. pushed).
    # Subclasses may override to kick off timers/async work, etc.
    def init(terminal:)
      [self, []]
    end

    # Handle a message (KeyEvent/MouseEvent/ResizeEvent/TickEvent/Command, etc.)
    # and return [self, commands].
    def update(_message, terminal:)
      [self, []]
    end

    # Render the session.
    #
    # By default, renders all views belonging to the session, ordered by z-index.
    # Subclasses can override, but should not mutate state here.
    def view(screen:, renderer:, terminal:)
      views.sort_by(&:z).each do |v|
        v.render(screen:, renderer:, terminal:, session: self)
      end
    end

    # Normalize a return value into the Charm tuple: [self, commands].
    #
    # Accepts:
    #   nil                  => [self, []]
    #   command              => [self, [command]]
    #   [command, ...]       => [self, [...]]
    #   [self, commands]     => [self, Array(commands)]
    #
    # Useful while migrating older sessions; Terminal can call this on whatever
    # `update` returns to get a uniform shape.
    def pack(ret)
      return [self, []] if ret.nil?

      # Already a Charm tuple
      if ret.is_a?(Array) && ret.length == 2 && ret[0].equal?(self)
        return [self, Array(ret[1])]
      end

      # Disambiguate:
      #   - [:beep] is a single command
      #   - [[:beep], [:open, "x"]] is a list of commands
      if ret.is_a?(Array)
        if ret.first.is_a?(Symbol)
          return [self, [ret]]
        else
          return [self, ret]
        end
      end

      [self, [ret]]
    end
  end
end
