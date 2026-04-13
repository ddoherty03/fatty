# frozen_string_literal: true

module FatTerm
  class Terminal
    class ProgressHandle
      attr_reader :terminal, :label, :total, :style, :role

      def initialize(terminal:, label:, total: nil, style: :percent, role: :status_info, trail_max: nil)
        @terminal = terminal
        @label = label.to_s
        @total = total&.to_i
        @style = style.to_sym
        @role = role
        @trail_max = trail_max&.to_i
        @trail = +""
        @current = 0
        refresh
      end

      def update(current:, total: @total, label: @label, indicator: nil, render: false)
        @current = current.to_i
        @total = total&.to_i
        @label = label.to_s
        append_indicator(indicator)
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

        @trail << ch[0]
        return unless @trail_max && @trail_max > 0

        @trail = @trail[-@trail_max, @trail_max] || @trail
      end

      def refresh
        terminal.set_status(render_text, role: role)
      end

      def render_text(suffix: nil)
        case style
        when :count
          total ? "#{label} [#{current}/#{total}]" : "#{label} [#{current}]"
        when :simple_percent
          total && total > 0 ? "#{label} #{percent}%" : "#{label}"
        when :trail
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
          trail = @trail[-limit, limit] || @trail
          "#{base}  #{trail}#{trailer}"
        else
          total && total > 0 ? "#{label} [#{current}/#{total}] #{percent}%" : "#{label} [#{current}]"
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

      def trail_limit(prefix, suffix = "")
        cols =
          if terminal.screen
            terminal.screen.cols.to_i
          else
            80
          end

        available = cols - prefix.length - suffix.length - 4
        available = 0 if available < 0
        available
      end
    end
  end
end
