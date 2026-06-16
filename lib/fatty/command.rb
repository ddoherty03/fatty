# frozen_string_literal: true

module Fatty
  class Command
    attr_reader :target, :action, :payload

    def initialize(target:, action:, payload: {})
      @target = target.to_sym
      @action = action.to_sym
      @payload = payload || {}
    end

    def inspect
      "Command: @target=#{@target}, @action=#{@action} @payload keys=#{@payload.keys}"
    end

    def self.terminal(action, **payload)
      new(target: :terminal, action: action, payload: payload)
    end

    def self.session(id, action, **payload)
      new(target: id, action: action, payload: payload)
    end

    def self.coerce(value)
      case value
      when Command
        value
      when Array
        coerce_array(value)
      else
        raise ArgumentError, "expected command, got #{value.inspect}"
      end
    end

    def self.normalize_list(value)
      result =
        case value
        when nil
          []
        when Command
          [value]
        when Array
          value.grep(Command)
        else
          []
        end

      result
    end

    def terminal?
      target == :terminal
    end

    def session?
      !terminal?
    end

    def id
      target unless terminal?
    end

    def self.coerce_array(value)
      domain, name, *rest = value
      case domain
      when :terminal
        new(target: :terminal, action: name, payload: { args: rest })
      when :send
        id, action_name, payload = name, *rest
        new(target: id, action: action_name, payload: payload || {})
      else
        raise ArgumentError, "unknown command domain #{domain.inspect}"
      end
    end
    private_class_method :coerce_array
  end
end
