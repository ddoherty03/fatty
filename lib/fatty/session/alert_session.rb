# frozen_string_literal: true

module Fatty
  # A pinned, non-interactive overlay session responsible for rendering alerts.
  #
  # It is intentionally dumb:
  #   - Terminal does not special-case alerts
  #   - other sessions emit commands like:
  #       [:send, :alert, :show, { level:, message: }]
  #       [:send, :alert, :clear, {}]
  class AlertSession < Session
    attr_reader :current

    def initialize(id: nil)
      super
      @current = nil
    end

    def update(command)
      log_update(command)
      case command.action
      when :show
        show_from_payload(command.payload[:alert] || command.payload)
      when :clear
        @current = nil unless @current&.sticky?
      end
      []
    end

    def view
      return unless visible?

      renderer.render_alert(current)
    end

    private

    def clear
      @current = nil
    end

    def visible?
      !!current
    end

    def show_from_payload(payload)
      return if payload.nil?

      if payload.is_a?(Fatty::Alert)
        @current = payload
        return
      end

      level = (payload[:level] || :info).to_sym
      text = payload[:text].to_s
      details = payload[:details]
      sticky  = !!payload[:sticky]
      @current = Fatty::Alert.new(level: level, text: text, details: details, sticky: sticky)
    end
  end
end
