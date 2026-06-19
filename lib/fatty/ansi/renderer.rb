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
        msg = Fatty::Ansi.truncate_visible(msg, width)
        visible = Fatty::Ansi.visible_length(msg)
        pad = width - visible
        sgr = sgr_for_spec(spec)
        padding = pad.positive? ? " " * pad : ""
        write_ansi("#{CSI}#{row + 1};#{col + 1}H", sgr, msg, sgr, padding, reset)
      end

      def render_segments_line(row:, col:, width:, segments:, palette:, fill_role: :output)
        rendered = +""
        visible = 0
        segments.each do |seg|
          spec = palette&.[](seg[:role])
          next unless spec

          remaining = width - visible
          break if remaining <= 0

          text = Fatty::Ansi.truncate_visible(seg[:text].to_s, remaining)
          next if text.empty?

          visible += Fatty::Ansi.visible_length(text)

          sgr =
            if seg[:style]
              sgr_for_style(seg[:style], fallback_spec: spec)
            else
              sgr_for_spec(spec)
            end

          rendered << sgr
          rendered << text
        end

        if visible < width
          spec = palette&.[](fill_role)
          rendered << sgr_for_spec(spec) if spec
          rendered << (" " * (width - visible))
        end
        write_ansi("#{CSI}#{row + 1};#{col + 1}H", rendered, reset)
      end

      def write_ansi(*parts)
        text = parts.join

        if defined?(::Curses) && ::Curses.respond_to?(:putp)
          ::Curses.putp(text)
        else
          io.write(text)
          io.flush
        end

        nil
      end

      def io
        @io || $stdout
      end

      def show_cursor
        "#{CSI}?25h"
      end

      def hide_cursor
        "#{CSI}?25l"
      end

      # simplecov:disable
      private

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

      def sgr_for_spec(spec)
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
        fg = rgb_for_style_color(style.fg, fallback: fallback_spec[:fg_rgb])
        bg = rgb_for_style_color(style.bg, fallback: fallback_spec[:bg_rgb])

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

      def rgb_for_style_color(color, fallback:)
        case color
        when Array
          color
        when Integer
          if color.between?(0, 15)
            Fatty::Color::ANSI_RGB[color]
          else
            Fatty::Color.xterm_rgb_for_index(color)
          end
        else
          fallback
        end
      end
    end
  end
end
