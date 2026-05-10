# lib/fatty/renderer/curses.rb
module Fatty
  class Renderer
    class Truecolor < Fatty::Renderer
      def initialize(...)
        super
        @legacy = Fatty::Curses::Renderer.new(
          screen: @screen,
          context: @context,
        )
      end

      def method_missing(name, ...)
        if @legacy.respond_to?(name)
          @legacy.public_send(name, ...)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @legacy.respond_to?(name, include_private) || super
      end

      def render_status(text, role: :status_info)
        Fatty.debug(
          "Truecolor#render_status text=#{text.inspect} role=#{role.inspect} rect=#{screen.status_rect.inspect}",
          tag: :render,
        )
        # @legacy.render_status(text, role: :status_info)
        # return
        state = [text.to_s, role]
        return if state == @last_status_state

        @last_status_state = state

        rect = screen.status_rect
        line = status_line(text, width: rect.cols)

        queue_ansi_line(
          row: rect.row,
          col: rect.col,
          width: rect.cols,
          text: line,
          role: role,
        )
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
        state = [
          alert&.message,
          alert&.role,
          alert&.details,
          screen.alert_rect.row,
          screen.alert_rect.cols,
        ]
        return if state == @last_alert_state

        @last_alert_state = state
        text = alert ? alert.format : ""
        queue_ansi_line(
          row: screen.alert_rect.row,
          col: screen.alert_rect.col,
          width: screen.alert_rect.cols,
          text: text,
          role: role,
        )
      end

      def begin_frame
        Fatty.debug("Truecolor adapter begin_frame", tag: :render)
        @legacy.begin_frame
      end

      def finish_frame
        Fatty.debug("Truecolor adapter finish_frame", tag: :render)
        @legacy.finish_frame
      end

      def restore_cursor(...)
        @legacy.restore_cursor(...)
      end

      def sync_backgrounds!
        @legacy.sync_backgrounds!
      end
    end
  end
end
