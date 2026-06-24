# frozen_string_literal: true

module Fatty
  class Alert
    attr_reader :role, :text, :details

    # Return a new Alert object
    #
    # @param message [String]
    # @param role [:good, :info, :warn, :error]
    # @param details [Hash|String]
    # @param sticky [Boolean]
    # @return [Alert]
    def initialize(text:, role: :info, details: nil, sticky: false)
      @text = text
      @role = role.to_sym
      @details = details
      @sticky  = !!sticky
    end

    # Return a new Alert object at role good
    #
    # @param msg [String]
    # @return [Alert] with role :good
    def self.good(msg)
      new(text: msg, role: :good)
    end

    # Return a new Alert object at role :info
    #
    # @param msg [String]
    # @return [Alert] with role :info
    def self.info(msg)
      new(text: msg, role: :info)
    end

    # Return a new Alert object at role :warn
    #
    # @param msg [String]
    # @return [Alert] with role :warn
    def self.warn(msg)
      new(text: msg, role: :warn)
    end

    # Return a new Alert object at role error
    #
    # @param msg [String]
    # @return [Alert] with role :error
    def self.error(msg)
      new(text: msg, role: :error)
    end

    # Translate the "level" to a "role" used by the renderers. The returned
    # roles are "composite" roles in the resolver in that they take the
    # background of the alert panel and apply a foreground color based on
    # severity.
    #   @param level [:info, :warn, :error]
    #   @return [Symbol] composite or semantic role
    # used by renderer (e.g., alert_good, :alert_info, :alert_warn, :alert_error)
    # def role
    #   case level
    #   when :good then :alert_good
    #   when :warn then :alert_warn
    #   when :error then :alert_error
    #   else :alert_info
    #   end
    # end

    # Build a string version of the Alert suitable for display to the user.
    def format
      icon =
        case role
        when :good then " ✔ "
        when :info then " ℹ "
        when :warn then " ⚠ "
        when :error then " ✖ "
        else "   "
        end
      details_str =
        if details.nil? || details.empty?
          ""
        else
          key_strs = []
          detail_key_order.each do |k|
            key_strs << "#{k}=#{details[k]}"
          end
          " (#{key_strs.join(' ')})"
        end
      "#{icon} #{text}#{details_str}"
    end

    # Return whether this Alert is sticky, meaning that it should not be
    # cleared until a key is presses or another Alert displayed
    #
    # @return [true, false] is this Alert sticky?
    def sticky?
      @sticky
    end

    def detail_key_order
      keys = []
      keys << :terminal if details.key?(:terminal)
      keys << :key if details.key?(:key)
      keys << :shift if details.key?(:shift)
      keys << :ctrl if details.key?(:ctrl)
      keys << :meta if details.key?(:meta)
      other_keys = details.keys - [:terminal, :key, :shift, :ctrl, :meta]
      keys + other_keys.sort
    end
  end
end
