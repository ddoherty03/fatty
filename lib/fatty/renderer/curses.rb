# lib/fatty/renderer/curses.rb

module Fatty
  class Renderer
    class Curses < Fatty::Renderer
      include Fatty::Curses::WindowStyling

      def initialize(...)
        super
        @legacy = Fatty::Curses::Renderer.new(
          screen: screen,
          context: context,
        )
      end

      def render_status(text, role: :status_info)
        state = [text.to_s, role]
        return if state == @last_status_state

        @last_status_state = state

        win = context.status_win
        cols = win.respond_to?(:maxx) ? win.maxx : screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)
        line = status_line(text, width: cols)

        win.erase
        win.attrset(attr)
        win.setpos(0, 0)
        win.addstr(Fatty::Ansi.strip(line))
        win.bkgdset(attr) if win.respond_to?(:bkgdset)

        stage_window(win)
        nil
      end

      def render_output(...)
        @legacy.render_output(...)
      end

      def render_input_field(...)
        @legacy.render_input_field(...)
      end

      def render_pager_field(...)
        @legacy.render_pager_field(...)
      end

      def render_popup(...)
        @legacy.render_popup(...)
      end

      def render_prompt_popup(...)
        @legacy.render_prompt_popup(...)
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state

        win = context.alert_win
        return unless win

        text = alert ? alert.format : ""
        text = Fatty::Ansi.strip(text)
        role = alert ? alert.role : :alert
        attr = pair_attr(role, fallback: pair_attr(:alert, fallback: ::Curses::A_REVERSE))
        cols = win.respond_to?(:maxx) ? win.maxx : screen.alert_rect.cols

        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        win.setpos(0, 0)
        win.addstr(text.ljust(cols)[0, cols])

        stage_window(win)
      end

      def begin_frame
        @legacy.begin_frame
      end

      def finish_frame
        @legacy.finish_frame
      end

      def restore_cursor(...)
        @legacy.restore_cursor(...)
      end

      private

      def available_colors
        ::Curses.colors
      end

      def after_apply_theme!
        context.apply_palette_to_curses!(palette)
      end

      def stage_window(win)
        win.noutrefresh
        @frame_touched = true
      end

      def draw_popup_frame(win, width:, height:)
        b = popup_border
        # top
        win.setpos(0, 0)
        win.addstr(b[:tl] + (b[:h] * (width - 2)) + b[:tr])
        # sides
        (1...(height - 1)).each do |y|
          win.setpos(y, 0)
          win.addstr(b[:v])
          win.setpos(y, width - 1)
          win.addstr(b[:v])
        end
        # bottom
        win.setpos(height - 1, 0)
        win.addstr(b[:bl] + (b[:h] * (width - 2)) + b[:br])
      end

      def render_field_into(win:, field:, row:, width:, base_attr:, region_attr:, suggestion_attr:)
        buf = field.buffer
        region =
          if buf.respond_to?(:region_range)
            buf.region_range
          end

        win.attrset(base_attr)
        win.setpos(row, 0)
        win.addstr(" " * width)
        win.setpos(row, 0)
        win.addstr(field.prompt_text.to_s)

        text = Fatty::Ansi.strip(buf.text.to_s)
        if region && region.begin < region.end
          max = text.length
          s = region.begin.clamp(0, max)
          e = region.end.clamp(0, max)

          before = text[0...s].to_s
          mid    = text[s...e].to_s
          after  = text[e..].to_s

          win.attrset(base_attr)
          win.addstr(before)

          win.attrset(region_attr)
          win.addstr(mid)

          win.attrset(base_attr)
          win.addstr(after)
        else
          win.attrset(base_attr)
          win.addstr(text)
        end

        suffix = buf.virtual_suffix.to_s
        unless suffix.empty?
          win.attrset(base_attr)
          win.attron(suggestion_attr) { win.addstr(suffix) }
        end
      end
    end
  end
end
