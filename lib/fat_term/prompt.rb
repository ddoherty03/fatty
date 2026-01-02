# frozen_string_literal: true

module FatTerm
  class Prompt
    def initialize(&block)
      @block = block
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
        Prompt.new { p.respond_to?(:to_s) ? p.to_s : "" }
      end
    end
  end
end
