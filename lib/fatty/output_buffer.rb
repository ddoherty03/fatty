# frozen_string_literal: true

module Fatty
  class OutputBuffer
    Fragment = Data.define(:text, :role)

    DEFAULT_MAX_LINES = 10_000

    attr_reader :lines
    attr_accessor :max_lines

    def initialize(max_lines: DEFAULT_MAX_LINES)
      @lines = []
      @fragments = []
      @scroll = 0
      @max_lines = Integer(max_lines)
      @line_open = false
    end

    def clear
      @lines.clear
      @fragments.clear
      @scroll = 0
      @line_open = false
      nil
    end


    # Append text to the output buffer. Text may contain complete lines,
    # partial lines, or both. Returns the number of lines trimmed.  The
    # Terminal can use this to adjust the Viewport.
    def append(text, role: nil)
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
          ntrimmed += append_fragment(part, role: role)
        end
      end

      ntrimmed
    end

    def fragments_for(index)
      @fragments[index] || []
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

    # simplecov:disable

    def append_fragment(fragment, role:)
      ntrimmed = 0
      if @line_open && @lines.any?
        @lines[-1] = "#{@lines[-1]}#{fragment}".freeze
        append_fragment_metadata(@fragments[-1], fragment, role)
      else
        ntrimmed += append_new_line(fragment, role: role)
        @line_open = true
      end
      ntrimmed
    end

    def append_new_line(line, role: nil)
      ntrimmed = 0

      if @lines.length >= @max_lines
        @lines.shift
        @fragments.shift
        ntrimmed = 1
      end

      @lines << line.to_s.dup.freeze
      @fragments << []
      append_fragment_metadata(@fragments[-1], line, role) unless line.to_s.empty?
      ntrimmed
    end

    def append_fragment_metadata(fragments, text, role)
      if fragments.any? && fragments[-1].role == role
        previous = fragments[-1]
        fragments[-1] = Fragment.new(
          text: "#{previous.text}#{text}".freeze,
          role: role,
        )
      else
        fragments << Fragment.new(
          text: text.to_s.dup.freeze,
          role: role,
        )
      end
    end
  end
end
