# frozen_string_literal: true

module Fatty
  class Terminal
    class Progress
      PARTIAL_BLOCKS = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"].freeze
      FULL_BLOCK = "█"
      EMPTY_BAR = ".".freeze

      SHADE_EMPTY = "░"
      SHADE_HALF  = "▒"
      SHADE_FULL  = "▓"

      BRAILLE_STEPS = ["⠀", "⣀", "⣄", "⣆", "⣇", "⣧", "⣷", "⣿"].freeze

      attr_reader :terminal, :label, :total, :style, :role

      def initialize(terminal:, label:, total: nil, style: :percent, role: :status_info, trail_max: nil, bar_width: 40)
        @terminal = terminal
        @label = label.to_s
        @total = total&.to_i
        @style = style.to_sym
        @role = role
        @trail_max = trail_max&.to_i
        @trail = []
        @current = 0
        @bar_width = bar_width.to_i
        @spinner_index = 0

        validate_total_requirement!

        refresh
      end

      def update(current: nil, total: @total, label: @label, indicator: nil, render: false)
        @current = current.to_i unless current.nil?
        @total = total&.to_i
        @label = label.to_s

        if style == :spinner
          advance_spinner
        else
          append_indicator(indicator)
        end

        refresh
        terminal.render_now if render
        self
      end

      def finish(message = nil, clear: false, role: @role, render: false, transient: true)
        if clear
          terminal.clear_status
        else
          text =
            if message && !message.empty?
              render_text(suffix: message)
            else
              render_text
            end
          terminal.set_status(text, role: role, transient: transient)
        end

        terminal.render_now if render
        self
      end

      def clear
        terminal.clear_status
        self
      end

      private

      attr_reader :current

      def append_indicator(indicator)
        ch = indicator.to_s
        return if ch.empty?

        @trail << ch
        trim_trail if @trail_max && @trail_max > 0
      end

      def refresh
        terminal.set_status(render_text, role: role)
      end

      def render_text(suffix: nil)
        case style
        when :count
          base = total ? "#{label} [#{current}/#{total}]" : "#{label} [#{current}]"
          suffix_text(base, suffix)
        when :simple_percent
          base = total && total > 0 ? "#{label} #{percent}%" : "#{label}"
          suffix_text(base, suffix)
        when :trail
          render_trail_text(suffix: suffix)
        when :bar
          render_bar_text(suffix: suffix, mode: :solid)
        when :unicode_bar
          render_bar_text(suffix: suffix, mode: :unicode)
        when :braille_bar
          render_bar_text(suffix: suffix, mode: :braille)
        when :spinner
          render_spinner_text(suffix: suffix)
        else
          base = total && total > 0 ? "#{label} [#{current}/#{total}] #{percent}%" : "#{label} [#{current}]"
          suffix_text(base, suffix)
        end
      end

      def percent
        ((current.to_f / total.to_f) * 100).round
      end

      def suffix_text(base, suffix)
        extra = suffix.to_s
        return base if extra.empty?

        "#{base}  #{extra}"
      end

      def render_trail_text(suffix: nil)
        base =
          if total && total > 0
            "#{label} [#{current}/#{total}] #{percent}%"
          else
            "#{label} [#{current}]"
          end

        extra = suffix.to_s
        trailer = extra.empty? ? "" : "  #{extra}"

        return "#{base}#{trailer}" if @trail.empty?

        limit = trail_limit(base, trailer)
        trail = @trail.last(limit).join
        "#{base}  #{trail}#{trailer}"
      end

      def trail_limit(prefix, suffix = "")
        cols =
          if terminal.screen
            terminal.screen.cols.to_i
          else
            80
          end

        available = cols - visible_length(prefix) - visible_length(suffix) - 4
        available = 0 if available < 0
        available
      end

      def limited_trail(limit)
        used = 0
        selected = []

        @trail.reverse_each do |item|
          width = Fatty::Ansi.visible_length(item)
          break if used + width > limit

          selected.unshift(item)
          used += width
        end

        selected.join
      end

      def trim_trail
        used = 0
        selected = []

        @trail.reverse_each do |item|
          width = Fatty::Ansi.visible_length(item)
          break if used + width > @trail_max

          selected.unshift(item)
          used += width
        end

        @trail = selected
      end

      def visible_length(text)
        Fatty::Ansi.visible_length(text)
      end

      def render_bar_text(suffix: nil, mode: :solid)
        base = label.to_s
        info = progress_info_text
        extra = suffix.to_s
        trailer = extra.empty? ? "" : "  #{extra}"

        bar_width = bar_width_for(base, info, trailer)
        bar =
          case mode
          when :unicode
            unicode_bar(bar_width)
          when :braille
            braille_bar(bar_width)
          else
            solid_bar(bar_width)
          end

        pieces = [base]
        pieces << "[#{bar}]" unless bar.empty?
        pieces << info unless info.empty?

        text = pieces.join(" ")
        text = "#{text}#{trailer}" unless trailer.empty?
        text
      end

      def render_spinner_text(suffix: nil)
        frame = spinner_frames[@spinner_index % spinner_frames.length]
        base =
          if total && total > 0
            "#{label} #{frame} #{percent}%"
          else
            "#{label} #{frame}"
          end

        suffix_text(base, suffix)
      end

      def progress_info_text
        if total && total > 0
          "#{percent}% [#{current}/#{total}]"
        else
          "[#{current}]"
        end
      end

      def bar_width_for(base, info, trailer)
        cols =
          if terminal.screen
            terminal.screen.cols.to_i
          else
            80
          end

        reserved = visible_length(base)
        reserved += 1 + visible_length(info) unless info.empty?
        reserved += visible_length(trailer) unless trailer.empty?

        # Space for:
        #   " ["
        #   "]"
        # around the bar
        available = cols - reserved - 4
        available = 0 if available < 0
        [available, @bar_width].min
      end

      def solid_bar(width)
        return "" if width <= 0

        ratio = progress_ratio
        filled = (ratio * width).round
        filled = 0 if filled < 0
        filled = width if filled > width

        empty = width - filled
        (FULL_BLOCK * filled) + (EMPTY_BAR * empty)
      end

      def unicode_bar(width)
        return "" if width <= 0

        raw = progress_ratio * width
        full = raw.floor

        # Show a transition block whenever the bar is in progress but not complete,
        # provided there is space for it.
        half =
          if progress_ratio.positive? && progress_ratio < 1.0 && full < width
            1
          else
            0
          end

        bar = +""
        bar << (SHADE_FULL * full)
        bar << SHADE_HALF if half == 1

        remaining = width - Fatty::Ansi.visible_length(bar)
        remaining = 0 if remaining < 0
        bar << (SHADE_EMPTY * remaining)
        bar
      end

      def braille_bar(width)
        return "" if width <= 0

        raw = progress_ratio * width
        full = raw.floor
        remainder = raw - full

        partial_idx = (remainder * (BRAILLE_STEPS.length - 1)).round
        partial_idx = 0 if partial_idx < 0
        partial_idx = BRAILLE_STEPS.length - 1 if partial_idx >= BRAILLE_STEPS.length

        bar = +""
        bar << (BRAILLE_STEPS[-1] * full)

        if progress_ratio.positive? && progress_ratio < 1.0 && full < width
          partial =
            if partial_idx.zero?
              BRAILLE_STEPS[1]
            else
              BRAILLE_STEPS[partial_idx]
            end
          bar << partial
        end

        remaining = width - Fatty::Ansi.visible_length(bar)
        remaining = 0 if remaining < 0
        bar << (BRAILLE_STEPS[0] * remaining)
        bar
      end

      def progress_ratio
        return 0.0 unless total && total > 0

        ratio = current.to_f / total.to_f
        ratio = 0.0 if ratio < 0.0
        ratio = 1.0 if ratio > 1.0
        ratio
      end

      def validate_total_requirement!
        return if style == :spinner
        return if total && total > 0

        raise ArgumentError, "progress style #{style.inspect} requires total:"
      end

      def advance_spinner
        @spinner_index = (@spinner_index + 1) % spinner_frames.length
      end

      def spinner_frames
        BRAILLE_STEPS[1..]
      end
    end
  end
end
