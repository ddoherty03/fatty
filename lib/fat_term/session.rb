# frozen_string_literal: true

module FatTerm
  # Base class for stateful runtime components.
  #
  # Charm/Bubbletea-style contract:
  #
  #   init(terminal:)               => commands
  #   update(message, terminal:)    => commands
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
      []
    end

    # Handle a message and return commands.
    def update(message, terminal:)
      case message[0]
      when :key
        update_key(message[1], terminal:)
      when :cmd
        update_cmd(message[1], message[2], terminal:)
      else
        []
      end
    end

    def update_key(_ev, terminal:)
      []
    end

    def update_cmd(_name, _payload, terminal:)
      []
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
  end
end

require_relative "session/alert_session"
require_relative "session/input_session"
require_relative "session/shell_session"
