# frozen_string_literal: true

module FatTerm
  class Renderer
    DETAIL_ORDER = %i[terminal key ctrl meta shift].freeze
    ALERT_INFO_PAIR    = 1
    ALERT_WARNING_PAIR = 2
    ALERT_ERROR_PAIR   = 3

    def initialize(screen)
      @screen = screen
    end

    def render(output:, input_field:, alert: nil)
      render_output(output)
      render_alert(alert)
      render_input_field(input_field)
      restore_cursor(input_field)
    end

    def restore_cursor(field)
      win = @screen.input_win
      win.setpos(0, field.cursor_x)
      win.refresh
    end

    def render_output(output)
      win = @screen.output_win
      win.clear

      height = @screen.rows - 2
      lines  = output.visible_lines(height)

      lines.each_with_index do |line, y|
        win.setpos(y, 0)
        win.clrtoeol
        win.addstr(line)
      end

      win.refresh
    end

    def render_input_field(field)
      win = @screen.input_win
      win.clear

      win.setpos(0, 0)
      win.clrtoeol
      win.addstr(field.prompt_text)
      win.addstr(field.buffer.text)

      win.setpos(0, field.cursor_x)
      win.refresh
    end

    def render_alert(alert)
      win = @screen.alert_win
      win.clear

      return win.refresh unless alert

      attr = alert_attr(alert)
      win.attron(attr) do
        text = format_alert(alert)
        win.addstr(text.ljust(@screen.cols))
      end

      win.refresh
    end

    private

    def alert_attr(alert)
      return Curses::A_REVERSE unless Curses.has_colors?

      pair =
        case alert.level
        when :error   then ALERT_ERROR_PAIR
        when :warning then ALERT_WARNING_PAIR
        else               ALERT_INFO_PAIR
        end

      Curses.color_pair(pair)
    end

    def format_alert(alert)
      parts = []

      parts <<
        case alert.level
        when :warning then "⚠"
        when :error   then "✖"
        else "ℹ"
        end
      parts << alert.message

      if alert.details && !alert.details.empty?
        details = DETAIL_ORDER.filter_map do |k|
          "#{k}=#{alert.details[k]} (#{alert.details[k].class})" if alert.details.key?(k)
        end.join(" ")
      end
      parts << "(#{details})"
      parts.join(" ")
    end
  end
end
