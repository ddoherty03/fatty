# frozen_string_literal: true

require "curses"

module FatTerm
  class Screen
    attr_reader :rows, :cols, :output_win, :input_win
    attr_accessor :diagnostic_sink

    def initialize
      Curses.init_screen
      Curses.raw
      Curses.noecho
      Curses.curs_set(1)
      Curses.stdscr.keypad(true)

      resize
    end

    def resize
      @rows = Curses.lines
      @cols = Curses.cols

      @output_win&.close
      @input_win&.close

      @output_win = Curses::Window.new(rows - 1, cols, 0, 0)
      @input_win  = Curses::Window.new(1, cols, rows - 1, 0)

      @output_win.scrollok(true)

      @input_win.keypad(true)
    end

    def close
      Curses.close_screen
    end

    # def read_key(debug: false)
    #   ch = @input_win.getch
    #   if debug
    #     diagnostic_sink.call("getch => #{ch.inspect} (#{ch.class}) #{KeyEvent::KEY_SYM_MAP[ch]}")
    #   end
    #   case ch
    #   when Integer
    #     case ch
    #     when 8, 127, Curses::KEY_BACKSPACE then KeyEvent.new(key: :backspace, ctrl: false)
    #     when 0..26
    #       # Ctrl-@ (0) through Ctrl-Z (26)
    #       letter = (ch + 96).chr
    #       KeyEvent.new(key: letter.to_sym, ctrl: true)
    #     when 27
    #       read_meta_key
    #     when Curses::KEY_LEFT
    #       KeyEvent.new(key: :left)
    #     when Curses::KEY_RIGHT
    #       KeyEvent.new(key: :right)
    #     when Curses::KEY_UP
    #       KeyEvent.new(key: :up)
    #     when Curses::KEY_DOWN
    #       KeyEvent.new(key: :down)
    #     when Curses::KEY_RESIZE
    #       KeyEvent.new(key: :resize)
    #     else
    #       if KeyMap::MAP[ch]
    #         KeyMap::MAP[ch]
    #       end
    #     end
    #   when String
    #     case ch
    #     when "\e"
    #       read_meta_key
    #     else
    #       KeyEvent.new(key: ch.to_sym, text: ch)
    #     end
    #   end
    # end

    def read_key(debug: false)
      ch = @input_win.getch
      if debug
        diagnostic_sink.call("getch => #{ch.inspect} (#{ch.class}) #{CURSES_TO_EVENT[ch]}")
      end
      if ch == 27 || ch == "\e"
        # Handle Meta
        read_meta_key
      elsif CURSES_TO_EVENT.key?(ch)
        # Known curses constants → normalized
        CURSES_TO_EVENT[ch]
      elsif ch.is_a?(Integer) && (0..26).include?(ch)
        # ASCII control keys
        KeyEvent.new(key: (ch + 96).chr.to_sym, ctrl: true)
      elsif ch.is_a?(String)
        # Printable characters
        KeyEvent.new(key: ch.to_sym, text: ch)
      else
        # Unknown integer → preserve
        KeyEvent.new(key: ch)
      end
    end

    def read_meta_key
      nxt = @input_win.getch
      return unless nxt

      if nxt.is_a?(String) && nxt.length == 1
        KeyEvent.new(key: nxt.to_sym, text: nxt, meta: true)
      else
        KeyEvent.new(key: nxt, meta: true)
      end
    end
  end
end
