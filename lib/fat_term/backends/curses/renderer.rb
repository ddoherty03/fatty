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

        POPUP_BORDER = {
          tl: "┌", tr: "┐",
          bl: "└", br: "┘",
          h:  "─",
          v:  "│"
        }.freeze

        POPUP_RESULTS_PAIR  = 10
        POPUP_INPUT_PAIR    = 11
        POPUP_FRAME_PAIR    = 12
        POPUP_SELECTED_PAIR = 13

        POPUP_SELECTED_GUTTER = "▶ "
        POPUP_UNSELECTED_GUTTER = "  "

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

        def popup_attr(pair_id, fallback)
          return fallback unless ::Curses.has_colors?

          ::Curses.color_pair(pair_id)
        end

        def render_popup(session:)
          win = session.win
          width = win.maxx
          height = win.maxy
          win.clear

          frame_attr = popup_attr(POPUP_FRAME_PAIR, ::Curses::A_NORMAL)
          win.attron(frame_attr) do
            draw_popup_frame(win, width: width, height: height)
          end

          inner_h = height - 2
          inner_w = width - 2
          inner = win.derwin(inner_h, inner_w, 1, 1)
          inner.erase

          # title (still on the frame)
          if session.title
            win.setpos(0, 2)
            win.addstr(" #{session.title} ")
          end

          # list area: inner_h-1 lines (last inner line is input)
          list_h = inner_h - 1
          list_w = inner_w

          results_attr  = popup_attr(POPUP_RESULTS_PAIR, ::Curses::A_NORMAL)
          input_attr    = popup_attr(POPUP_INPUT_PAIR, ::Curses::A_REVERSE)
          selected_attr = popup_attr(POPUP_SELECTED_PAIR, ::Curses::A_REVERSE)

          items = session.filtered
          sel   = session.selected

          start = 0
          if sel >= list_h
            start = sel - list_h + 1
          end

          inner.attron(results_attr) do
            (0...list_h).each do |i|
              idx = start + i
              is_sel = (idx == sel)
              row_attr = is_sel ? selected_attr : results_attr
              inner.attrset(row_attr)

              inner.setpos(i, 0)
              inner.addstr(" " * list_w)
              inner.setpos(i, 0)

              next if idx >= items.length

              gutter = idx == sel ? POPUP_SELECTED_GUTTER : POPUP_UNSELECTED_GUTTER
              s = items[idx].to_s
              s = s[0, list_w - gutter.length]
              row = gutter + s

              if idx == sel
                inner.attron(selected_attr) { inner.addstr(row.ljust(list_w)) }
              else
                inner.addstr(row.ljust(list_w))
              end
            end
          end

          inner.attron(input_attr) do
            # input line at bottom (inside inner)
            inner.setpos(inner_h - 1, 0)
            inner.addstr(" " * list_w)
            inner.setpos(inner_h - 1, 0)

            prompt = session.field.prompt_text.to_s
            text   = session.field.buffer.text.to_s

            line = (prompt + text)[0, list_w]
            inner.addstr(line.ljust(list_w))
          end

          # cursor: move in outer window coords
          cursor_in_inner = session.field.cursor_x.clamp(0, list_w - 1)
          win.setpos(1 + (inner_h - 1), 1 + cursor_in_inner)

          inner.refresh
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

        def draw_popup_frame(win, width:, height:)
          b = POPUP_BORDER
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
      end
    end
  end
end
