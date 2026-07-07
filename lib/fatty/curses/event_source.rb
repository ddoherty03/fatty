# frozen_string_literal: true

module Fatty
  module Curses
    class EventSource
      MOUSE_BSTATE_BUTTON_MAP = {
        ::Curses::BUTTON1_PRESSED => :left_pressed,
        ::Curses::BUTTON1_RELEASED => :left_released,
        ::Curses::BUTTON1_CLICKED => :left_clicked,
        ::Curses::BUTTON1_DOUBLE_CLICKED => :left_double_clicked,
        ::Curses::BUTTON1_TRIPLE_CLICKED => :left_triple_clicked,

        ::Curses::BUTTON2_PRESSED => :middle_pressed,
        ::Curses::BUTTON2_RELEASED => :middle_released,
        ::Curses::BUTTON2_CLICKED => :middle_clicked,
        ::Curses::BUTTON2_DOUBLE_CLICKED => :middle_double_clicked,
        ::Curses::BUTTON2_TRIPLE_CLICKED => :middle_triple_clicked,

        ::Curses::BUTTON3_PRESSED => :right_pressed,
        ::Curses::BUTTON3_RELEASED => :right_released,
        ::Curses::BUTTON3_CLICKED => :right_clicked,
        ::Curses::BUTTON3_DOUBLE_CLICKED => :right_double_clicked,
        ::Curses::BUTTON3_TRIPLE_CLICKED => :right_triple_clicked
      }.freeze

      SCROLL_UP_BSTATE = ::Curses::BUTTON4_PRESSED
      SCROLL_DOWN_BSTATE = 0x10000000
      MOUSE_MODIFIER_MASK =
        ::Curses::BUTTON_CTRL |
        ::Curses::BUTTON_ALT |
        ::Curses::BUTTON_SHIFT

      ESCAPE_LOOKAHEAD_MS = 0

      BRACKETED_PASTE_START = "[200~"
      BRACKETED_PASTE_END   = "\e[201~"

      attr_reader :context, :key_decoder

      def initialize(context: Context.new, key_decoder: nil, poll_ms: 200)
        @context = context
        @key_decoder = key_decoder || KeyDecoder.new
        @poll_ms = poll_ms.to_i
        configure_input_polling!
      end

      def next_event
        raw = read_raw
        return unless raw

        if raw.is_a?(Fatty::MouseEvent)
          Command.session(:active, :key, event: raw)
        elsif raw.is_a?(Array) && raw.first == :paste
          # This :terminal_paste is a terminal bracketed-paste event, not an
          # editor paste action. Treat the pasted bytes as one insert
          # operation instead of decoding them as individual key events.
          Command.session(:active, :terminal_paste, text: raw.last)
        elsif (ev = @key_decoder.decode(raw))
          if ev.key == :resize
            Command.terminal(:resize)
          else
            Command.session(:active, :key, event: ev)
          end
        else
          Fatty.warn("undecoded input: #{raw.inspect}", tag: :input)
          nil
        end
      end

      private

      # simplecov:disable

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

        pending = read_pending_raw
        return pending if pending

        window.timeout = @poll_ms if window.respond_to?(:timeout=)

        ch = window.getch
        return if ch == -1
        return unless ch

        log_keycode(ch)

        if ch.is_a?(Integer) && ch == ::Curses::KEY_MOUSE
          mouse = ::Curses.getmouse
          Fatty.debug("EventSource#read_raw: bstate=#{mouse&.bstate}", tag: :mouse)
          return decode_mouse(mouse)
        end

        return ch unless escape_char?(ch)

        read_escape_raw(ch)
      end

      def read_escape_raw(ch)
        nxt = with_window_timeout(escape_lookahead_ms) { window.getch }

        return ch if nxt == -1 || !nxt

        if csi_prefix?(nxt)
          suffix = read_escape_suffix
          seq = "[" + suffix
          if seq == BRACKETED_PASTE_START
            [:paste, read_bracketed_paste]
          else
            push_pending_raw(*suffix.chars.reverse)
            push_pending_raw(nxt)
            ch
          end
        else
          [ch, nxt]
        end
      end

      def read_pending_raw
        @pending_raw ||= []
        @pending_raw.shift
      end

      def push_pending_raw(*values)
        @pending_raw ||= []
        values.each do |value|
          @pending_raw.unshift(value)
        end
      end

      def escape_lookahead_ms
        Fatty::Config.config.fetch(:esc_delay, ESCAPE_LOOKAHEAD_MS).to_i
      end

      def escape_char?(ch)
        ch.is_a?(Integer) && ch == 27
      end

      def csi_prefix?(ch)
        ch == "[".ord || ch == "["
      end

      def log_keycode(ch)
        return unless Fatty::Config.config.dig(:log, :tags)&.include?(:keycode)

        Fatty.debug(
          :curses_getch,
          tag: :keycode,
          ch_class: ch.class.name,
          ch_inspect: ch.inspect,
          ch_int: (ch.is_a?(Integer) ? ch : nil),
          ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil),
        )
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

        Fatty::MouseEvent.new(
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
        button_state = bstate & ~MOUSE_MODIFIER_MASK
        return :scroll_up if (button_state & SCROLL_UP_BSTATE).positive?
        return :scroll_down if (button_state & SCROLL_DOWN_BSTATE).positive?

        MOUSE_BSTATE_BUTTON_MAP.each do |mask, button|
          return button if (button_state & mask).positive?
        end

        nil
      end

      def mouse_button_pressed?(button_state, const_name)
        ::Curses.const_defined?(const_name) && (button_state & ::Curses.const_get(const_name)).positive?
      end

      def read_escape_suffix
        suffix = +""
        done = false

        until done
          ch = with_window_timeout(0) { window.getch }

          if ch == -1 || !ch
            done = true
          else
            suffix << raw_char_to_s(ch)
            done = true if suffix.end_with?("~")
          end
        end

        suffix
      end

      def read_bracketed_paste
        text = +""
        done = false
        limit = 1_000_000
        hit_limit = false

        until done
          ch = window.getch

          if ch == -1 || !ch
            done = true
          else
            text << raw_char_to_s(ch)
            if text.end_with?(BRACKETED_PASTE_END)
              text = text.delete_suffix(BRACKETED_PASTE_END)
              done = true
            end
          end

          if text.length >= limit
            hit_limit = true
            done = true
          end
        end

        Fatty.debug("EventSource#read_bracketed_paste: hit limit #{limit}", tag: :keycode) if hit_limit
        text
      end

      def raw_char_to_s(ch)
        case ch
        when String
          ch
        when Integer
          ch.between?(0, 255) ? ch.chr : ""
        else
          ""
        end
      end
    end
  end
end
