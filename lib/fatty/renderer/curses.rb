# lib/fatty/renderer/curses.rb

module Fatty
  class Renderer
    class Curses < Fatty::Renderer
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
        win.addstr(line)
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

      def render_alert(...)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state

        text =
          if alert.nil?
            ""
          else
            format_alert(alert)
          end
        win = context.alert_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols

        attr =
          if alert.nil?
            pair_attr(:info, fallback: ::Curses::A_REVERSE)
          else
            alert_attr(alert)
          end
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
    end
  end
end
