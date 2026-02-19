# frozen_string_literal: true

module FatTerm
  # For holding the environment in which an action is executed
  class ActionEnvironment
    attr_accessor :session, :terminal, :event, :buffer, :field, :pager

    def initialize(
          session: nil,
          terminal: nil,
          event: nil,
          buffer: nil,
          field: nil,
          pager:nil
        )
      @session = session
      @terminal = terminal
      @event = event
      @buffer = buffer
      @field = field
      @pager = pager
    end

    def to_s
      parts = []
      parts << "session: #{session}" if session
      parts << "terminal: #{terminal}" if terminal
      parts << "event: #{event.to_s[0..90]}" if event
      parts << "buffer: #{buffer}" if buffer
      parts << "field: #{field}" if field
      parts << "pager: #{pager}" if pager
      parts.join('; ')
    end
  end
end
