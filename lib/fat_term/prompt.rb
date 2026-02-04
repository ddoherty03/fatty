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

    def self.ensure(p)
      case p
      when Prompt
        p
      when Proc
        Prompt.new(&p)
      else
        Prompt.new { "> " }
      end
    end
  end
end
