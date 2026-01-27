module FatTerm
  class AlertPanel
    attr_reader :current

    # Show an alert.
    #
    # Accepts either:
    #   - an Alert object, or
    #   - keyword args (compatible with Terminal command payloads)
    #
    # Supported keyword payloads:
    #   { level:, message: }   # preferred
    #   { level:, text: }      # backward compatible
    #   { details:, sticky: }  # optional
    def show(alert = nil, level: :info, message: nil, text: nil, details: nil, sticky: false, **_ignored)
      if alert.is_a?(Alert)
        @current = alert
        return @current
      end

      msg = message || text
      msg = msg.to_s

      @current = Alert.new(message: msg, level: level, details: details, sticky: sticky)
    end

    def clear
      @current = nil
    end

    def visible?
      !@current.nil?
    end
  end
end
