module Fatty
  class Alert
    attr_reader :level, :message, :details

    # Return a new Alert object
    #
    # @param message [String]
    # @param level [:info, :warning, :error]
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

    # Return a new Alert object at level warning
    #
    # @param msg [String]
    # @return [Alert] with level warning
    def self.warning(msg)
      new(message: msg, level: :warning)
    end

    # Return a new Alert object at level error
    #
    # @param msg [String]
    # @return [Alert] with level error
    def self.error(msg)
      new(message: msg, level: :error)
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
