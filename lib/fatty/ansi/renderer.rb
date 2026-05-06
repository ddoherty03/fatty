# frozen_string_literal: true

module Fatty
  module Ansi
    class Renderer
      CSI = "\e["

      def initialize(io: nil)
        @io = io
      end

      def render_line(row:, col:, width:, text:, role:, palette:)
        spec = palette&.[](role)
        return unless spec

        msg = text.to_s.tr("\r\n", " ")
        msg = msg.ljust(width)[0, width]

        sgr = sgr_for_role(spec)

        io.write(
          "\e7",
          "#{CSI}#{row + 1};#{col + 1}H",
          sgr,
          msg,
          reset,
          "\e8",
        )
        io.flush
        nil
      end

      def render_segments_line(row:, col:, width:, segments:, palette:, fill_role: :output)
        rendered = +""
        visible = 0

        segments.each do |seg|
          spec = palette&.[](seg[:role])
          next unless spec

          text = seg[:text].to_s
          remaining = width - visible
          break if remaining <= 0

          text = text[0, remaining]
          visible += text.length

          sgr =
            if seg[:style]
              sgr_for_style(seg[:style], fallback_spec: spec)
            else
              sgr_for_role(spec)
            end

          rendered << sgr
          rendered << text
        end

        if visible < width
          spec = palette&.[](fill_role)
          rendered << sgr_for_role(spec) if spec
          rendered << (" " * (width - visible))
        end

        io.write(
          "\e7",
          "#{CSI}#{row + 1};#{col + 1}H",
          rendered,
          reset,
          "\e8",
        )
        io.flush
        nil
      end

      private

      def io
        @io || $stdout
      end

      def save_cursor
        "#{CSI}s"
      end

      def restore_cursor
        "#{CSI}u"
      end

      def reset
        "#{CSI}0m"
      end

      def move_to(row, col)
        "#{CSI}#{row + 1};#{col + 1}H"
      end

      def sgr_for_role(spec)
        fg = spec[:fg_rgb]
        bg = spec[:bg_rgb]
        codes = []

        Array(spec[:attrs]).each do |attr|
          case attr.to_sym
          when :bold
            codes << "1"
          when :dim
            codes << "2"
          when :underline
            codes << "4"
          when :reverse
            if fg && bg
              fg, bg = bg, fg
            else
              codes << "7"
            end
          end
        end

        parts = [reset]
        parts << "#{CSI}#{codes.join(';')}m" unless codes.empty?
        parts << "#{CSI}38;2;#{fg[0]};#{fg[1]};#{fg[2]}m" if fg
        parts << "#{CSI}48;2;#{bg[0]};#{bg[1]};#{bg[2]}m" if bg

        return reset if parts.empty?

        parts.join
      end

      def sgr_for_style(style, fallback_spec:)
        fg =
          if style.fg
            if style.fg.between?(0, 15)
              Fatty::Color::ANSI_RGB[style.fg]
            else
              Fatty::Color.xterm_rgb_for_index(style.fg)
            end
          else
            fallback_spec[:fg_rgb]
          end

        bg =
          if style.bg
            if style.bg.between?(0, 15)
              Fatty::Color::ANSI_RGB[style.bg]
            else
              Fatty::Color.xterm_rgb_for_index(style.bg)
            end
          else
            fallback_spec[:bg_rgb]
          end

        codes = []
        codes << "1" if style.bold
        codes << "3" if style.italic
        codes << "4" if style.underline
        codes << "9" if style.strike

        if style.reverse
          if fg && bg
            fg, bg = bg, fg
          else
            codes << "7"
          end
        end

        parts = [reset]
        parts << "#{CSI}#{codes.join(';')}m" unless codes.empty?
        parts << "#{CSI}38;2;#{fg[0]};#{fg[1]};#{fg[2]}m" if fg
        parts << "#{CSI}48;2;#{bg[0]};#{bg[1]};#{bg[2]}m" if bg

        parts.join
      end
    end
  end
end
