# frozen_string_literal: true

module FatTerm
  class Viewport
    attr_accessor :top
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
      @top = @top.clamp(0, max_top(lines.size))
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

    # Jump to the very top.
    def page_top
      @top = 0
    end

    # Jump to the very bottom.
    def page_bottom(lines)
      @top = max_top(lines.length)
    end

    def reset
      @top = 0
    end
  end
end
