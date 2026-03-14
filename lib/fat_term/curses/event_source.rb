# frozen_string_literal: true

module FatTerm
  module Curses
    class EventSource
      MOUSE_BUTTON_MAP = {
        ::Curses::BUTTON1_PRESSED        => :left_pressed,
        ::Curses::BUTTON1_RELEASED       => :left_released,
        ::Curses::BUTTON1_CLICKED        => :left_clicked,
        ::Curses::BUTTON1_DOUBLE_CLICKED => :left_double_clicked,
        ::Curses::BUTTON1_TRIPLE_CLICKED => :left_triple_clicked,

        ::Curses::BUTTON2_PRESSED        => :middle_pressed,
        ::Curses::BUTTON2_RELEASED       => :middle_released,
        ::Curses::BUTTON2_CLICKED        => :middle_clicked,
        ::Curses::BUTTON2_DOUBLE_CLICKED => :middle_double_clicked,
        ::Curses::BUTTON2_TRIPLE_CLICKED => :middle_triple_clicked,

        ::Curses::BUTTON3_PRESSED        => :right_pressed,
        ::Curses::BUTTON3_RELEASED       => :right_released,
        ::Curses::BUTTON3_CLICKED        => :right_clicked,
        ::Curses::BUTTON3_DOUBLE_CLICKED => :right_double_clicked,
        ::Curses::BUTTON3_TRIPLE_CLICKED => :right_triple_clicked
      }.freeze

      ESCAPE_LOOKAHEAD_MS = 0

      attr_reader :context, :key_decoder

      def initialize(context:, key_decoder:, poll_ms: 200)
        @context = context
        @key_decoder = key_decoder
        @poll_ms = poll_ms.to_i
        configure_input_polling!
      end

      def next_event
        raw = read_raw
        return unless raw

        if raw.is_a?(FatTerm::MouseEvent)
          return [:key, raw]
        end

        ev = @key_decoder.decode(raw)
        return unless ev

        [:key, ev]
      end

      private

      def window
        context.input_win
      end

      def configure_input_polling!
        win = window
        return unless win

        # Make getch return nil periodically so Terminal can keep rendering,
        # which allows output to animate smoothly.
        win.timeout = @poll_ms if win.respond_to?(:timeout=)
      end

      def read_raw
        return unless window

        # The input window can be replaced when the layout changes (resize,
        # apply_layout, etc.). Ensure polling is always enabled on the
        # current window so getch doesn't block and Terminal can tick.
        window.timeout = @poll_ms if window.respond_to?(:timeout=)

        ch = window.getch
        return if ch == -1
        return unless ch

        if ch.is_a?(Integer) && ch == ::Curses::KEY_MOUSE
          mouse = ::Curses.getmouse
          FatTerm.log("EventSource#read_raw: bstate=#{mouse&.bstate}", tag: :mouse)
          return decode_mouse(mouse)
        end

        if FatTerm::Config.config.dig(:log, :tags)&.include?(:keycode)
          FatTerm.debug(
            :curses_getch,
            tag: :keycode,
            ch_class: ch.class.name,
            ch_inspect: ch.inspect,
            ch_int: (ch.is_a?(Integer) ? ch : nil),
            ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil),
          )
        end

        # The single character might be the ASCII ESCAPE (27), in which case, we
        # have a meta sequence that needs handling.
        if ch.is_a?(Integer) && ch == 27
          nxt = with_window_timeout(ESCAPE_LOOKAHEAD_MS) { window.getch }
          return ch if nxt == -1 || !nxt

          if FatTerm::Config.config.dig(:log, :tags)&.include?(:keycode)
            FatTerm.log(
              :curses_getch,
              tag: :keycode,
              ch_class: ch.class.name,
              ch_inspect: ch.inspect,
              ch_int: (ch.is_a?(Integer) ? ch : nil),
              ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil),
            )
          end
          [ch, nxt]
        else
          ch
        end
      end

      def with_window_timeout(ms)
        result = nil
        win = window
        if win&.respond_to?(:timeout=)
          begin
            win.timeout = ms
            result = yield
          ensure
            win.timeout = @poll_ms
          end
        else
          result = yield
        end
        result
      end

      def decode_mouse(mouse)
        return unless mouse&.respond_to?(:bstate)

        bstate = mouse.bstate

        ctrl  = (bstate & ::Curses::BUTTON_CTRL).positive?
        meta  = (bstate & ::Curses::BUTTON_ALT).positive?
        shift = (bstate & ::Curses::BUTTON_SHIFT).positive?

        button = mouse_button_from_bstate(bstate)
        return unless button

        FatTerm::MouseEvent.new(
          button: button,
          x: mouse.x,
          y: mouse.y,
          ctrl: ctrl,
          meta: meta,
          shift: shift,
          raw: mouse,
        )
      end

      def mouse_button_from_bstate(bstate)
        return :scroll_up   if (bstate & ::Curses::BUTTON4_PRESSED).positive?
        return :scroll_down if (bstate & ::Curses::BUTTON5_PRESSED).positive?

        MOUSE_BUTTON_MAP.each do |mask, button|
          return button if (bstate & mask).positive?
        end

        nil
      end
    end
  end
end
