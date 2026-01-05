module FatTerm
  class Alert
    attr_reader :level, :message, :details, :sticky

    def initialize(message:, level: :info, details: nil, sticky: false)
      @message = message
      @level   = level    # :info, :warning, :error
      @details = details  # Hash or String
      @sticky  = sticky   # require explicit dismiss
    end

    def self.info(msg)
      new(message: msg, level: :info)
    end

    def self.warning(msg)
      new(message: msg, level: :warning)
    end

    def self.error(msg)
      new(message: msg, level: :error)
    end
  end
end
