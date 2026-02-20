# frozen_string_literal: true

module FatTerm
  # Counter accumulates and otherwise managed a numeric prefix count (e.g.,
  # "12").
  #
  # Intended usage:
  #   counter.push_digit(1)
  #   counter.push_digit(2)
  #   n = counter.consume(default: 1)  # => 12 (and clears)
  #
  class Counter
    MAX_DIGITS = 6

    def initialize
      @digits = +""
    end

    def active?
      !@digits.empty?
    end

    def clear!
      @digits.clear
    end

    def digits
      @digits.dup
    end

    def push_digit(n)
      s = n.to_i.to_s
      if @digits.length < MAX_DIGITS
        @digits << s
      end
      self
    end

    def value
      if active?
        @digits.to_i
      end
    end

    def consume(default: nil)
      n = value
      if n.nil?
        default
      else
        clear!
        n
      end
    end
  end
end
