# frozen_string_literal: true

module FatTerm
  class Prompt
    DEFAULT = "> "

    def initialize(value = nil, &block)
      @block =
        if block
          block
        elsif value
          -> { value.to_s }
        else
          -> { DEFAULT }
        end
    end

    def text
      @block.call.to_s
    end

    def to_s
      "<Prompt:#{object_id}> `#{text}`"
    end
    alias_method :inspect, :to_s

    def self.ensure(p)
      case p
      when Prompt
        p
      when Proc
        Prompt.new(&p)
      when String
        Prompt.new(p)
      else
        Prompt.new(DEFAULT)
      end
    end
  end
end
