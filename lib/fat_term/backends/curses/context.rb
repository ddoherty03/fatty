# frozen_string_literal: true

require "curses"

module FatTerm
  module Backends
    module Curses
      # Context represents the active curses environment.
      #
      # It owns:
      #   - curses initialization and shutdown
      #   - terminal mode configuration
      #   - window lifecycle
      #
      # Context does NOT:
      #   - read input
      #   - decode keys
      #   - render UI
      #
      # Those responsibilities belong to EventSource and Renderer.
      #
      # Context exists so that all curses state is centralized and never leaks
      # into Sessions, Views, or Terminal.
      class Context
        attr_reader :output_win, :alert_win
        attr_reader :rows, :cols

        def initialize
          @started = false
        end

        def input_win
          @input_win
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

          ::Curses.init_pair(1, ::Curses::COLOR_WHITE,  ::Curses::COLOR_BLUE)
          ::Curses.init_pair(2, ::Curses::COLOR_BLACK,  ::Curses::COLOR_YELLOW)
          ::Curses.init_pair(3, ::Curses::COLOR_WHITE,  ::Curses::COLOR_RED)

          # Popup theme (basic 8-color palette)
          # Pair IDs live in the renderer, but we mirror them here as literals to
          # keep initialization centralized and avoid cross-layer coupling.
          #
          # Results panel: yellow on blue (your request)
          # ::Curses.init_pair(10, ::Curses::COLOR_YELLOW, ::Curses::COLOR_BLUE)
          ::Curses.init_pair(10, 226, 18)
          # Input line: black on cyan (distinct from results)
          ::Curses.init_pair(11, ::Curses::COLOR_BLACK,  ::Curses::COLOR_CYAN)
          # Frame: white on blue (optional)
          ::Curses.init_pair(12, ::Curses::COLOR_WHITE,  ::Curses::COLOR_BLUE)
          # Selected row: blue on yellow (optional; cleaner than A_REVERSE)
          # ::Curses.init_pair(13, ::Curses::COLOR_BLUE,   ::Curses::COLOR_YELLOW)
          ::Curses.init_pair(13, 17, 226)
        end

        # Allocate or reallocate windows using Screen layout.
        def apply_layout(screen)
          ensure_started!

          @rows = screen.rows
          @cols = screen.cols

          close_windows

          out = screen.output_rect
          inp = screen.input_rect
          alr = screen.alert_rect

          @output_win = ::Curses::Window.new(out.rows, out.cols, out.row, out.col)
          @input_win  = ::Curses::Window.new(inp.rows, inp.cols, inp.row, inp.col)
          @alert_win  = ::Curses::Window.new(alr.rows, alr.cols, alr.row, alr.col)

          @output_win.scrollok(true)
          @input_win.keypad(true)

          self
        end

        def close
          close_windows
          ::Curses.close_screen if @started
          @started = false
        end

        private

        def ensure_started!
          return if @started

          raise "Curses::Context not started"
        end

        def close_windows
          @output_win&.close
          @input_win&.close
          @alert_win&.close

          @output_win = nil
          @input_win  = nil
          @alert_win  = nil
        end
      end
    end
  end
end
