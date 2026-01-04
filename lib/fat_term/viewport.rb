# frozen_string_literal: true

module FatTerm
  class Viewport
    attr_reader :top, :height

    def initialize(top: 0, height:)
      @top = top
      @height = height
    end

    def slice(lines)
      lines[@top, @height] || []
    end

    def max_top(lines)
      [lines.length - @height, 0].max
    end

    def clamp!(lines)
      @top = [[@top, 0].max, max_top(lines)].min
    end

    def scroll_up(lines, n = 1)
      @top -= n
      clamp!(lines)
    end

    def scroll_down(lines, n = 1)
      @top += n
      clamp!(lines)
    end

    def reset
      @top = 0
    end

    def page_up
      scroll_up(@height)
    end

    def page_down(max:)
      scroll_down(@height, max:)
    end
  end
end
