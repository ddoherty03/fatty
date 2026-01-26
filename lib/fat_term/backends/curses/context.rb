# frozen_string_literal: true

require "curses"

module FatTerm
  module Backends
    module Curses
      # The Curses Context represents the active curses environment for FatTerm.
      #
      # It is responsible for:
      #   - initializing and shutting down the curses library
      #   - configuring terminal modes (raw, noecho, keypad, colors)
      #   - owning the lifecycle of curses windows
      #
      # Context provides shared backend state used by other curses components,
      # including the Renderer and EventSource.
      #
      # Context deliberately does NOT:
      #   - interpret keyboard or mouse input
      #   - decode raw key sequences
      #   - render application UI
      #   - manage application state
      #
      # In the overall architecture:
      #
      #   Terminal → orchestrates runtime and sessions
      #   Session  → owns application state and behavior
      #   View     → decides what should be drawn
      #   Renderer → performs drawing using curses
      #   Context  → owns curses initialization and window resources
      #
      # All direct interaction with the curses library is contained within the
      # FatTerm::Backends::Curses namespace.  Code outside this namespace must not
      # depend on curses or call Curses.* directly.
      #
      # This separation allows FatTerm to remain structured and testable while
      # accommodating the inherently stateful nature of curses.
      class Context
        attr_reader :output_win, :input_win, :alert_win
        attr_reader :rows, :cols

        def initialize(diagnostic_sink: nil)
          @diagnostic_sink = diagnostic_sink
          @started = false
        end

        def started?
          @started
        end

        def start
          return self if @started

          ::Curses.init_screen
          ::Curses.raw
          ::Curses.noecho
          ::Curses.curs_set(1)
          ::Curses.stdscr.keypad(true)
          setup_colors

          @started = true
          self
        end

        def setup_colors
          return unless ::Curses.has_colors?

          ::Curses.start_color
          ::Curses.use_default_colors

          ::Curses.init_pair(1, ::Curses::COLOR_WHITE, ::Curses::COLOR_BLUE)   # info
          ::Curses.init_pair(2, ::Curses::COLOR_BLACK, ::Curses::COLOR_YELLOW) # warning
          ::Curses.init_pair(3, ::Curses::COLOR_WHITE, ::Curses::COLOR_RED)    # error
        end

        # Make windows match the given Screen layout.
        # Screen is backend-neutral and should expose rects.
        def apply_layout(screen)
          ensure_started!

          @rows = screen.rows
          @cols = screen.cols

          recreate_windows(screen)
          self
        end

        def recreate_windows(screen)
          close_windows

          out = screen.output_rect
          inp = screen.input_rect
          alr = screen.alert_rect

          @output_win = ::Curses::Window.new(out.rows, out.cols, out.row, out.col)
          @input_win  = ::Curses::Window.new(inp.rows, inp.cols, inp.row, inp.col)
          @alert_win  = ::Curses::Window.new(alr.rows, alr.cols, alr.row, alr.col)

          @output_win.scrollok(true)
          @input_win.keypad(true)
        end

        def close
          close_windows
          ::Curses.close_screen if @started
          @started = false
          self
        end

        private

        def close_windows
          @output_win&.close
          @input_win&.close
          @alert_win&.close
          @output_win = @input_win = @alert_win = nil
        end

        def ensure_started!
          return if @started
          raise "FatTerm::Backends::Curses::Context not started (call #start)"
        end
      end
    end
  end
end
