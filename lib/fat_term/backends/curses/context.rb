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

          # Important: ::Curses.colors is not reliable until after start_color.
          ::Curses.start_color
          ::Curses.use_default_colors if ::Curses.respond_to?(:use_default_colors)

          # Resolve and apply theme/config colors using stable pair IDs from
          # FatTerm::Colors::Pairs.
          #
          # Reads:
          #   FatTerm::Config.config[:ui][:color]
          #
          # and falls back to theme defaults (if any).
          FatTerm::Colors::Palette.apply!(
            FatTerm::Config.config,
            available_colors: ::Curses.colors,
          )
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

        def apply_theme!(theme_name)
          cfg = FatTerm::Config.config

          # Make sure ui/color exists, then override theme in-memory.
          ui = cfg[:ui] ||= {}
          color = ui[:color] ||= {}
          color[:theme] = theme_name.to_sym

          FatTerm::Colors::Palette.apply!(cfg, available_colors: ::Curses.colors)
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
