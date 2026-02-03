# frozen_string_literal: true

module FatTerm
  # A pinned, non-interactive overlay session responsible for rendering alerts.
  #
  # It is intentionally dumb:
  #   - Terminal does not special-case alerts
  #   - other sessions emit commands like:
  #       [:send, :alert, :show, { level:, message: }]
  #       [:send, :alert, :clear, {}]
  class AlertSession < Session
    attr_reader :current

    def initialize
      super(views: [FatTerm::Views::AlertView.new(z: 1_000)])
      @current = nil
    end

    def id
      :alert
    end

    def update(message, terminal:)
      if message.is_a?(Array) && message[0] == :cmd
        name = message[1]
        payload = message[2] || {}

        case name
        when :show
          show_from_payload(payload)
        when :clear
          @current = nil unless @current&.sticky?
        end
      end

      []
    end

    def view(screen:, renderer:, terminal:)
      renderer.render_alert(@current)
    end

    def show_from_payload(payload)
      return if payload.nil?

      if payload.is_a?(FatTerm::Alert)
        @current = payload
        return
      end

      level   = (payload[:level] || :info).to_sym
      message = (payload[:message] || payload[:text]).to_s
      details = payload[:details]
      sticky  = !!payload[:sticky]

      @current = FatTerm::Alert.new(level: level, message: message, details: details, sticky: sticky)
    end
  end
end
