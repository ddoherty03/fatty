# frozen_string_literal: true

module Fatty
  # A pinned, non-interactive overlay session responsible for rendering alerts.
  class AlertSession < Session
    attr_reader :current

    def initialize(id: nil)
      super
      @current = nil
    end

    #########################################################################################
    # Session Protocol
    #########################################################################################

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
      renderer.render_alert(self)
    end

    def state
      [
        current&.text.dup.freeze,
        current&.role,
        current&.details,
        renderer.screen.alert_rect.row,
        renderer.screen.alert_rect.cols,
        renderer.theme_version
      ]
    end

    private

    # simplecov:disable

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

      role = (payload[:role] || :info).to_sym
      text = payload[:text].to_s
      details = payload[:details]
      sticky  = !!payload[:sticky]
      @current = Fatty::Alert.new(role: role, text: text, details: details, sticky: sticky)
    end
  end
end
