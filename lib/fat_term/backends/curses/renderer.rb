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
        attr_reader :context, :screen

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
          win.addstr(field.buffer.text)

          win.setpos(0, field.cursor_x)
          win.refresh
        end

        def render_alert(alert)
          win = context.alert_win
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
  end
end
