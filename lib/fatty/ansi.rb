# frozen_string_literal: true

require_relative "ansi/renderer"

module Fatty
  module Ansi
  end
end

module Fatty
  # Parse ANSI escape sequences (primarily SGR, i.e. "\e[...m") into styled text
  # segments. This is intentionally curses-agnostic: the renderer/context decides
  # how to map Style -> terminal attributes / color pairs.
  #
  # Supported SGR:
  # - 0 reset
  # - 1 bold
  # - 22 normal intensity (clears bold)
  # - 7 reverse
  # - 27 reverse off
  # - 30-37 / 90-97 foreground (16-color)
  # - 40-47 / 100-107 background (16-color)
  # - 38;5;n foreground (256-color index)
  # - 48;5;n background (256-color index)
  #
  # Everything else is ignored (but does not break parsing).
  module Ansi
    ESC = "\e"
    CSI = "#{ESC}["
    COMBINING_MARK_RE = /\p{M}/

    ANSI_ESCAPE = /
      \e\[ [0-9;?]* [A-Za-z]   | # CSI sequences
      \e\] .*? (?:\a|\e\\)     | # OSC sequences
      \e[@-Z\\-_]                # single-char escapes
    /x

    Style = Struct.new(
      :fg,
      :bg,
      :bold,
      :italic,
      :underline,
      :strike,
      :reverse,
      keyword_init: true,
    ) do
      def dup
        self.class.new(
          fg: fg,
          bg: bg,
          bold: bold,
          italic: italic,
          underline: underline,
          strike: strike,
          reverse: reverse,
        )
      end

      def normalize!
        self.bold = !!bold
        self.italic = !!italic
        self.underline = !!underline
        self.strike = !!strike
        self.reverse = !!reverse
        self
      end

      def self.default
        new(
          fg: nil,
          bg: nil,
          bold: false,
          italic: false,
          underline: false,
          strike: false,
          reverse: false,
        )
      end
    end

    # Remove any ANSI escape sequences from text.
    def self.strip(text)
      text.to_s.gsub(ANSI_ESCAPE, "")
    end

    # Public: segment a string into [[text, Style], ...]
    #
    # The returned Style objects are independent copies; you can safely mutate
    # them downstream if you want.
    def self.segment(str, base: nil)
      s = str.to_s
      style = (base ? base.dup : Style.default).normalize!

      out = []
      buf = +""

      i = 0
      n = s.bytesize
      while i < n
        if s.getbyte(i) == 27 # ESC
          # Flush buffered text before processing escape
          unless buf.empty?
            out << [buf, style.dup]
            buf = +""
          end

          consumed = consume_escape!(s, i, style)
          if consumed > 0
            i += consumed
          else
            # Not a recognized/complete escape; treat ESC as literal.
            buf << ESC
            i += 1
          end
        else
          buf << s.byteslice(i, 1)
          i += 1
        end
      end

      out << [buf, style.dup] unless buf.empty?
      merge_adjacent_segments(out)
    end

    def self.merge_adjacent_segments(segments)
      return segments if segments.length <= 1

      merged = []
      segments.each do |text, st|
        if merged.empty?
          merged << [text.dup, st]
        else
          prev_text, prev_st = merged[-1]
          if same_style?(prev_st, st)
            prev_text << text
          else
            merged << [text.dup, st]
          end
        end
      end

      merged
    end

    def self.same_style?(a, b)
      a.fg == b.fg &&
        a.bg == b.bg &&
        a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.strike == b.strike &&
        a.reverse == b.reverse
    end

    # Internal: attempts to consume an ANSI escape starting at position i.
    # Returns number of bytes consumed, or 0 if not recognized.
    def self.consume_escape!(s, i, style)
      consumed = 0

      # Only support CSI sequences for now: ESC '[' ... final
      if s.bytesize >= i + 2 && s.getbyte(i + 1) == 91 # '['
        # We only actively handle SGR: ... 'm'
        j = i + 2
        params = +""

        while j < s.bytesize
          b = s.getbyte(j)
          if (b >= 48 && b <= 57) || b == 59 # 0-9 or ';'
            params << b
            j += 1
          else
            final = b
            consumed = (j - i) + 1
            if final == 109 # 'm'
              apply_sgr!(style, parse_params(params))
            end
            break
          end
        end
      end
      consumed
    end

    def self.parse_params(param_str)
      # SGR with empty params means reset
      parts =
        if param_str.empty?
          ["0"]
        else
          param_str.split(";")
        end

      parts.map do |p|
        p = "0" if p.nil? || p.empty?
        Integer(p, 10) rescue 0
      end
    end

    def self.apply_sgr!(style, params)
      params = [0] if params.empty?
      i = 0
      while i < params.length
        code = params[i].to_i
        case code
        when 0
          style.fg = nil
          style.bg = nil
          style.bold = false
          style.italic = false
          style.underline = false
          style.strike = false
          style.reverse = false
        when 1
          style.bold = true
        when 3
          style.italic = true
        when 4
          style.underline = true
        when 7
          style.reverse = true
        when 9
          style.strike = true
        when 22
          style.bold = false
        when 23
          style.italic = false
        when 24
          style.underline = false
        when 27
          style.reverse = false
        when 29
          style.strike = false
        when 30..37
          style.fg = code - 30
        when 39
          style.fg = nil
        when 40..47
          style.bg = code - 40
        when 49
          style.bg = nil
        when 90..97
          style.fg = code - 90 + 8
        when 100..107
          style.bg = code - 100 + 8
        when 38
          if params[i + 1].to_i == 5 && params[i + 2]
            style.fg = params[i + 2].to_i
            i += 2
          end
        when 48
          if params[i + 1].to_i == 5 && params[i + 2]
            style.bg = params[i + 2].to_i
            i += 2
          end
        end
        i += 1
      end
      style.normalize!
    end

    def self.sgr_for(style)
      codes = []
      codes << 1 if style.bold
      codes << 3 if style.italic
      codes << 4 if style.underline
      codes << 9 if style.strike
      codes << 7 if style.reverse

      if style.fg
        if style.fg.between?(0, 7)
          codes << 30 + style.fg
        elsif style.fg.between?(8, 15)
          codes << 90 + (style.fg - 8)
        else
          codes.concat([38, 5, style.fg])
        end
      end

      if style.bg
        if style.bg.between?(0, 7)
          codes << 40 + style.bg
        elsif style.bg.between?(8, 15)
          codes << 100 + (style.bg - 8)
        else
          codes.concat([48, 5, style.bg])
        end
      end

      if codes.empty?
        ""
      else
        "\e[#{codes.join(';')}m"
      end
    end

    def self.plain_text(str)
      segment(str).map { |text, _style| text }.join
    end

    # Return the screen width taken up by an ANSI-encoded sequence, taking
    # into account Unicode combining characters.
    def self.visible_length(str)
      segment(str.to_s).sum do |segment_text, _style|
        segment_text.each_char.count { |ch| visible_char?(ch) }
      end
    end

    # Don't count a "combining character" as visible in the sense that it
    # contributes to width.  It overlays the prior character so it does not
    # add to the visible width.
    def self.visible_char?(ch)
      !ch.match?(COMBINING_MARK_RE)
    end

    def self.truncate_visible(str, max)
      remaining = max.to_i
      out = +""

      if remaining.positive?
        segment(str).each do |text, style|
          break unless remaining.positive?

          chunk = text.each_char.take(remaining).join
          unless chunk.empty?
            out << sgr_for(style)
            out << chunk
            remaining -= chunk.length
          end
        end

        out << "\e[0m" unless out.empty?
      end

      out
    end

    private_class_method :consume_escape!, :parse_params, :apply_sgr!
    private_class_method :merge_adjacent_segments, :same_style?, :sgr_for
  end
end
