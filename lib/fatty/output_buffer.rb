# frozen_string_literal: true

module Fatty
  class OutputBuffer
    DEFAULT_MAX_LINES = 10_000

    attr_reader :lines
    attr_accessor :max_lines

    def initialize(max_lines: DEFAULT_MAX_LINES)
      @lines = []
      @scroll = 0
      @max_lines = Integer(max_lines)
      @line_open = false
    end

    # Append text to the output buffer. Text may contain complete lines,
    # partial lines, or both. Returns the number of lines trimmed.  The
    # Terminal can use this to adjust the Viewport.
    def append(text)
      ntrimmed = 0
      str = text.to_s
      return ntrimmed if str.empty?

      str.split(/(\n)/).each do |part|
        if part == "\n"
          if @line_open
            @line_open = false
          else
            ntrimmed += append_new_line("")
          end
        elsif !part.empty?
          ntrimmed += append_fragment(part)
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

    private

    def append_fragment(fragment)
      ntrimmed = 0
      if @line_open && @lines.any?
        @lines[-1] = "#{@lines[-1]}#{fragment}".freeze
      else
        ntrimmed += append_new_line(fragment)
        @line_open = true
      end
      ntrimmed
    end

    def append_new_line(line)
      ntrimmed = 0

      if @lines.length >= @max_lines
        @lines.shift
        ntrimmed = 1
      end

      @lines << line.to_s.dup.freeze
      ntrimmed
    end
  end
end
