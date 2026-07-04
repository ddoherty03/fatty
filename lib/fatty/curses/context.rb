# frozen_string_literal: true

require "curses"

module Fatty
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
    # into Sessions or Terminal.
    class Context
      DEFAULT_ESC_DELAY = 0

      attr_reader :input_win, :output_win, :status_win, :alert_win
      attr_reader :rows, :cols, :palette, :truecolor

      def initialize
        @started = false
      end

      def start
        return self if @started

        configure_escape_delay!
        ::Curses.init_screen
        MouseConstants.ensure!

        ::Curses.raw
        ::Curses.noecho
        ::Curses.curs_set(1)
        ::Curses.stdscr.keypad(true)
        ::Curses.mousemask(::Curses::ALL_MOUSE_EVENTS)
        enable_bracketed_paste!
        setup_colors
        @truecolor = truecolor_enabled?
        @started = true
        self
      end

      def started?
        @started
      end

      def environment
        data = {
          started: started?,
          truecolor: truecolor,
          key_min: ::Curses::KEY_MIN,
          key_max: ::Curses::KEY_MAX,
        }
        if started?
          data.merge(
            lines: ::Curses.lines,
            cols: ::Curses.cols,
            has_colors: ::Curses.has_colors?,
            colors: ::Curses.colors,
            color_pairs: ::Curses.color_pairs,
            can_change_color: ::Curses.can_change_color?,
          )
        else
          data
        end
      rescue StandardError
        {}
      end

      def configure_escape_delay!
        delay =
          if ENV["ESCDELAY"]
            ENV["ESCDELAY"].to_i
          else
            Fatty::Config.config.dig(:esc_delay)&.to_i
          end
        delay = DEFAULT_ESC_DELAY if delay.nil? || delay.negative?
        if ::Curses.respond_to?(:set_escdelay)
          ::Curses.set_escdelay(delay)
        else
          ENV["ESCDELAY"] = delay.to_s
        end
        Fatty.info("ESC delay set to #{delay} ms", tag: :input)
      end

      def setup_colors
        return unless ::Curses.has_colors?

        reset_ansi_pairs!
        ::Curses.start_color
        ::Curses.use_default_colors if ::Curses.respond_to?(:use_default_colors)

        theme_spec = Fatty::Themes::Manager.roles(Fatty::Themes::Manager.current) || {}
        palette = Fatty::Colors::Palette.compile(
          theme_spec,
          available_colors: ::Curses.colors,
        )
        apply_palette(palette)
      end

      # Allocate or reallocate windows using Screen layout.
      def apply_layout(screen)
        ensure_started!

        @rows = screen.rows
        @cols = screen.cols

        close_windows

        out = screen.output_rect
        sts = screen.status_rect
        inp = screen.input_rect
        alr = screen.alert_rect

        @output_win = ::Curses::Window.new(out.rows, out.cols, out.row, out.col)
        @status_win = ::Curses::Window.new(sts.rows, sts.cols, sts.row, sts.col)
        @input_win  = ::Curses::Window.new(inp.rows, inp.cols, inp.row, inp.col)
        @alert_win  = ::Curses::Window.new(alr.rows, alr.cols, alr.row, alr.col)

        # We do our own viewport/paging; allowing curses to scroll introduces
        # “mystery” blank lines if a newline slips into output
        @output_win.scrollok(true)
        @input_win.keypad(true)
        self
      end

      def close
        close_windows
        disable_bracketed_paste! if @started
        ::Curses.close_screen if @started
        @started = false
      end

      # Map a Fatty::Ansi::Style to a curses attribute.
      #
      # - If style has no explicit fg/bg, we keep the themed role pair.
      # - If style specifies fg/bg, we allocate/init a curses pair on demand.
      #
      # Note: this is intentionally independent of theme roles; it is for SGR
      # output runs inside the output pane.
      def truecolor_enabled?
        cfg = Fatty::Config.config

        setting =
          if cfg.key?(:truecolor)
            cfg[:truecolor]
          else
            "auto"
          end
        @truecolor =
          case setting.to_s.downcase
          when "true", "yes", "on", "1"
            true
          when "false", "no", "off", "0"
            false
          else
            Fatty::Env.truecolor_detected?
          end
        Fatty.info(
          "truecolor=#{@truecolor} setting=#{setting.inspect} " \
            "TERM=#{ENV['TERM'].inspect} COLORTERM=#{ENV['COLORTERM'].inspect} " \
            "TERM_PROGRAM=#{ENV['TERM_PROGRAM'].inspect} TMUX=#{ENV.key?('TMUX')}",
          tag: :themes,
        )
        @truecolor
      end

      def apply_palette(palette)
        reset_ansi_pairs!

        if ::Curses.has_colors?
          ::Curses.start_color
          ::Curses.use_default_colors if ::Curses.respond_to?(:use_default_colors)

          palette.each_value do |entry|
            next unless entry[:pair]

            ::Curses.init_pair(entry[:pair], entry[:fg], entry[:bg])
          end
        end

        @palette = palette
      end

      # Return a curses color-pair id for an ANSI foreground/background pair.
      #
      # This owns the dynamic ANSI pair cache. Renderers decide which fg/bg
      # indexes they want; Context decides whether a pair can be allocated.
      def ansi_pair_for(fg, bg, fallback_pair_id:)
        return fallback_pair_id unless ::Curses.has_colors?

        @ansi_pairs ||= {}
        @ansi_pair_limit ||= begin
                               ::Curses.color_pairs.to_i
                             rescue StandardError
                               256
                             end

        key = [fg.nil? ? -1 : fg.to_i, bg.nil? ? -1 : bg.to_i]
        cached = @ansi_pairs[key]
        return cached if cached

        start_id = Fatty::Colors::Pairs::ROLE_TO_PAIR.values.max + 1
        @ansi_next_pair_id ||= start_id
        @ansi_next_pair_id = start_id if @ansi_next_pair_id < start_id

        if @ansi_pair_limit.positive? && @ansi_next_pair_id >= @ansi_pair_limit
          Fatty.debug(
            "ansi_pair_for exhausted next=#{@ansi_next_pair_id.inspect} " \
            "limit=#{@ansi_pair_limit.inspect} fg=#{fg.inspect} bg=#{bg.inspect} " \
            "fallback=#{fallback_pair_id.inspect}",
            tag: :themes,
          )
          @ansi_pairs[key] = fallback_pair_id
        else
          pair_id = @ansi_next_pair_id
          @ansi_next_pair_id += 1

          ::Curses.init_pair(
            pair_id,
            fg.nil? ? -1 : fg.to_i,
            bg.nil? ? -1 : bg.to_i,
          )

          @ansi_pairs[key] = pair_id
        end

        @ansi_pairs[key]
      end

      def reset_ansi_pairs!
        @ansi_pairs = {}
        @ansi_next_pair_id = nil
        @ansi_pair_limit = nil
      end

      private

      # simplecov:disable

      def ensure_started!
        return if @started

        raise "Curses::Context not started"
      end

      def close_windows
        @output_win&.close
        @input_win&.close
        @alert_win&.close
        @status_win&.close

        @output_win = nil
        @input_win = nil
        @alert_win = nil
        @status_win = nil
      end

      def enable_bracketed_paste!
        $stdout.write("\e[?2004h")
        $stdout.flush
        nil
      end

      def disable_bracketed_paste!
        $stdout.write("\e[?2004l")
        $stdout.flush
        nil
      end
    end
  end
end
