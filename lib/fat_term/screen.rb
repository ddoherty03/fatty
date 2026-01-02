# frozen_string_literal: true

require "curses"

module FatTerm
  class Screen
    attr_reader :rows, :cols, :output_win, :input_win, :alert_win
    attr_accessor :diagnostic_sink

    def initialize
      Curses.init_screen
      Curses.raw
      Curses.noecho
      Curses.curs_set(1)
      Curses.stdscr.keypad(true)
      setup_colors

      resize
    end

    def setup_colors
      return unless Curses.has_colors?

      Curses.start_color
      Curses.use_default_colors

      Curses.init_pair(1, Curses::COLOR_WHITE,  Curses::COLOR_BLUE)   # info
      Curses.init_pair(2, Curses::COLOR_BLACK,  Curses::COLOR_YELLOW) # warning
      Curses.init_pair(3, Curses::COLOR_WHITE,  Curses::COLOR_RED)    # error
    end

    def resize
      @rows = Curses.lines
      @cols = Curses.cols

      @output_win&.close
      @input_win&.close

      @output_win = Curses::Window.new(rows - 2, cols, 0, 0)
      @input_win  = Curses::Window.new(1, cols, rows - 2, 0)
      @alert_win  = Curses::Window.new(1, cols, rows - 1, 0)

      @output_win.scrollok(true)

      @input_win.keypad(true)
    end

    def close
      Curses.close_screen
    end

    def read_raw
      ch = @input_win.getch
      return unless ch

      if ch.is_a?(Integer) && ch == 27
        read_meta_sequence(ch)
      else
        ch
      end
    end

    def read_meta_sequence(esc)
      nxt = @input_win.getch
      return esc unless nxt

      [esc, nxt]
    end
  end
end
