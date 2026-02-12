# frozen_string_literal: true

module FatTerm
  module Backends
    module Curses
      # The Curses Renderer is responsible for drawing FatTerm views using curses.
      #
      # Renderer provides the drawing API used by View objects.  Views never call
      # curses directly; instead, they request drawing operations from the Renderer.
      #
      # Responsibilities:
      #   - translate high-level draw requests into curses window operations
      #   - apply colors, attributes, and cursor placement
      #   - respect layout information provided by FatTerm::Screen
      #   - refresh windows at frame boundaries
      #
      # Renderer deliberately does NOT:
      #   - read keyboard or mouse input
      #   - decode raw key sequences
      #   - manage session state
      #   - decide which views should be rendered
      #
      # In the architecture:
      #
      #   Session  → owns state
      #   View     → decides *what* to draw
      #   Renderer → decides *how* to draw
      #   Context  → owns curses and window lifecycle
      #
      # Terminal coordinates rendering by collecting Views from active Sessions,
      # ordering them by z-index, and invoking Renderer methods during each frame.
      #
      # Renderer is backend-specific.  Other renderers may exist in the future
      # (e.g., ANSI, headless, test), but Views and Sessions remain unchanged.
      class Renderer
        attr_reader :context
        attr_accessor :screen

        DETAIL_ORDER = %i[terminal key ctrl meta shift].freeze
        ALERT_INFO_PAIR    = 1
        ALERT_WARNING_PAIR = 2
        ALERT_ERROR_PAIR   = 3

        def initialize(context:, screen:)
          @context = context
          @screen = screen
        end

        def render(output:, input_field:, alert:, viewport:)
          render_output(output, viewport:)
          render_input_field(input_field)
          render_alert(alert)
          restore_cursor(input_field)
        end

        def restore_cursor(field)
          win = context.input_win
          win.setpos(0, field.cursor_x)
          win.refresh
        end

        def render_output(output, viewport:)
          win = context.output_win
          win.clear

          lines = viewport.slice(output.lines)

          lines.each_with_index do |line, y|
            win.setpos(y, 0)
            win.clrtoeol
            win.addstr(line)
          end

          win.refresh
        end

        def render_input_field(field)
          win = context.input_win
          win.clear

          win.setpos(0, 0)
          win.clrtoeol
          win.addstr(field.prompt_text)

          buf = field.buffer
          text = buf.text.to_s

          region =
            if buf.respond_to?(:region_range)
              buf.region_range
            end

          if region && region.begin < region.end
            # Render the buffer in three parts, before region, region, and
            # after region.
            max = text.length
            s = region.begin.clamp(0, max)
            e = region.end.clamp(0, max)

            before = text[0...s].to_s
            mid    = text[s...e].to_s
            after  = text[e..].to_s

            win.addstr(before)
            win.attron(::Curses::A_REVERSE) { win.addstr(mid) }
            win.addstr(after)
          else
            win.addstr(text)
          end

          win.setpos(0, field.cursor_x)
          win.refresh
        end

        def render_alert(alert)
          win = context.alert_win
          win.clear
          win.setpos(0, 0)
          win.clrtoeol

          if alert.nil?
            # Always draw a bar so the "panel" is visible even when empty.
            if ::Curses.has_colors?
              win.attron(::Curses.color_pair(ALERT_INFO_PAIR)) { win.addstr(" ".ljust(@screen.cols)) }
            else
              win.attron(::Curses::A_REVERSE) { win.addstr(" ".ljust(@screen.cols)) }
            end
          else
            attr = alert_attr(alert)
            win.attron(attr) do
              text = format_alert(alert)
              win.addstr(text.ljust(@screen.cols))
            end
          end
          win.refresh
        end

        def render_popup(session:)
          # pick geometry
          cols = ::Curses.cols
          rows = ::Curses.lines

          width  = [cols - 4, 80].min
          height = [rows - 4, 12].min

          x = (cols - width) / 2
          y = (rows - height) / 2

          win = session.win
          win.clear
          win.box(?|, ?-)

          # title
          if session.title
            win.setpos(0, 2)
            win.addstr(" #{session.title} ")
          end

          # list area: height-3 lines (border + input line)
          list_h = height - 3
          list_w = width - 2

          items = session.filtered
          sel   = session.selected

          start = 0
          if sel >= list_h
            start = sel - list_h + 1
          end

          (0...list_h).each do |i|
            idx = start + i
            win.setpos(1 + i, 1)
            win.clrtoeol
            next if idx >= items.length

            s = items[idx].to_s
            s = s[0...list_w]

            if idx == sel
              win.attron(::Curses::A_REVERSE) { win.addstr(s) }
            else
              win.addstr(s)
            end
          end

          # input line at bottom
          win.setpos(height - 2, 1)
          win.clrtoeol
          win.addstr(session.field.prompt_text)
          win.addstr(session.field.buffer.text.to_s)

          # cursor
          cursor_x = (1 + session.field.cursor_x).clamp(1, width - 2)
          win.setpos(height - 2, cursor_x)

          win.refresh
        end

        private

        def alert_attr(alert)
          return ::Curses::A_REVERSE unless ::Curses.has_colors?

          pair =
            case alert.level
            when :error   then ALERT_ERROR_PAIR
            when :warning then ALERT_WARNING_PAIR
            else               ALERT_INFO_PAIR
            end

          ::Curses.color_pair(pair)
        end

        def format_alert(alert)
          icon =
            case alert.level
            when :warning then "⚠"
            when :error   then "✖"
            else               "ℹ"
            end

          msg = alert.message.to_s

          details_str = ""
          if alert.details.respond_to?(:empty?) ? !alert.details.empty? : !!alert.details
            if alert.details.is_a?(Hash)
              details_str =
                " (" +
                DETAIL_ORDER.filter_map { |k| "#{k}=#{alert.details[k]}" if alert.details.key?(k) }.join(" ") +
                ")"
            else
              details_str = " (#{alert.details})"
            end
          end

          "  #{icon} #{msg}#{details_str}"
        end
      end
    end
  end
end
