# frozen_string_literal: true

module FatTerm
  class Viewport
    attr_reader :top
    attr_accessor :height

    def initialize(top: 0, height:)
      @top    = top
      @height = height
    end

    def adjust_for_trim(n)
      @top = [@top - n, 0].max
    end

    def at_bottom?(total_lines = nil)
      return false unless total_lines

      @top >= max_top(total_lines)
    end

    def slice(lines)
      lines[@top, @height] || []
    end

    def max_top(total_lines)
      [total_lines - @height, 0].max
    end

    def clamp!(lines)
      @top = [[@top, 0].max, max_top(lines.size)].min
    end

    def scroll_up(lines, n = 1)
      @top -= n
      clamp!(lines)
    end

    def scroll_down(lines, n = 1)
      @top += n
      clamp!(lines)
    end

    def scroll_to_bottom(lines)
      @top = max_top(lines.length)
    end

    def page_up(lines)
      scroll_up(lines, @height)
    end

    def page_down(lines)
      scroll_down(lines, @height)
    end

    def reset
      @top = 0
    end
  end
end
