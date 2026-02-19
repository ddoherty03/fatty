# frozen_string_literal: true

module FatTerm
  class OutputBuffer
    DEFAULT_MAX_LINES = 10_000

    attr_reader :lines
    attr_accessor :max_lines

    def initialize(max_lines: DEFAULT_MAX_LINES)
      @lines = []
      @scroll = 0
      @max_lines = Integer(max_lines)
    end

    # Append each line of the text, possibly containing multiple lines, to the
    # buffer up to max_lines. Return the number of lines dropped from the
    # buffer.  The Terminal can use this to adjust the Viewport.
    def append(text)
      ntrimmed = 0

      text.to_s.each_line do |line|
        if @lines.length < @max_lines
          # Fast path: buffer not full yet
          @lines << line.chomp.freeze
        else
          # Buffer full: drop one old line, then append new one
          @lines.shift
          ntrimmed += 1
          @lines << line.chomp.freeze
        end
      end

      ntrimmed
    end

    def visible_lines(height)
      start = [@lines.length - height - @scroll, 0].max
      @lines[start, height] || []
    end

    def scroll_up
      @scroll += 1
    end

    def scroll_down
      @scroll -= 1 if @scroll.positive?
    end
  end
end
