module Fatty
  class Alert
    DETAIL_ORDER = %i[terminal key ctrl meta shift].freeze

    attr_reader :level, :message, :details

    # Return a new Alert object
    #
    # @param message [String]
    # @param level [:info, :warn, :error]
    # @param details [Hash|String]
    # @param sticky [Boolean]
    # @return [Alert]
    def initialize(message:, level: :info, details: nil, sticky: false)
      @message = message
      @level = level.to_sym
      @details = details
      @sticky  = !!sticky
    end

    # Return a new Alert object at level info
    #
    # @param msg [String]
    # @return [Alert] with level info
    def self.info(msg)
      new(message: msg, level: :info)
    end

    # Return a new Alert object at level warn
    #
    # @param msg [String]
    # @return [Alert] with level warn
    def self.warn(msg)
      new(message: msg, level: :warn)
    end

    # Return a new Alert object at level error
    #
    # @param msg [String]
    # @return [Alert] with level error
    def self.error(msg)
      new(message: msg, level: :error)
    end

    # Translate the "level" to a "role" used by the renderers.
    # @param level [:info, :warn, :error]
    # @return [Symbol] role used by renderer (e.g., :info, :warn, :error)
    def role
      level
    end

    # Build a string version of the Alert suitable for display to the user.
    def format
      icon =
        case level
        when :warn then "⚠"
        when :error   then "✖"
        else               "ℹ"
        end
      msg = message.to_s
      details_str = ""
      if details.respond_to?(:empty?) ? !details.empty? : !!details
        if details.is_a?(Hash)
          details_str =
            " (" +
            DETAIL_ORDER.filter_map { |k| "#{k}=#{details[k]}" if details.key?(k) }.join(" ") +
            ")"
        else
          details_str = " (#{details})"
        end
      end
      "#{icon} #{msg}#{details_str}"
    end

    # Return whether this Alert is sticky, meaning that it should not be
    # cleared until a key is presses or another Alert displayed
    #
    # @return [true, false] is this Alert sticky?
    def sticky?
      @sticky
    end
  end
end
