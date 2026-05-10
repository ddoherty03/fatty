# lib/fatty/renderer/curses.rb
module Fatty
  class Renderer
    class Truecolor < Fatty::Renderer
      def initialize(...)
        super
        @legacy = Fatty::Curses::Renderer.new(
          screen: @screen,
          context: @context,
        )
        @ansi_renderer = Fatty::Ansi::Renderer.new
        @pending_ansi_draws = []
      end

      def method_missing(name, ...)
        if @legacy.respond_to?(name)
          @legacy.public_send(name, ...)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @legacy.respond_to?(name, include_private) || super
      end

      def render_status(text, role: :info)
        state = status_state(text, role)
        return if state == @last_status_state

        @last_status_state = state
        spec = merged_role_spec(:status, role)
        queue_ansi_line(
          row: screen.status_rect.row,
          col: screen.status_rect.col,
          width: screen.status_rect.cols,
          text: text,
          spec: spec,
        )
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state
        text = alert ? alert.format : ""
        spec = merged_role_spec(:alert, alert ? alert.role : :alert)
        queue_ansi_line(
          row: screen.alert_rect.row,
          col: screen.alert_rect.col,
          width: screen.alert_rect.cols,
          text: text,
          spec: spec,
        )
      end

      def render_output(output, viewport:, highlights: nil)
        lines = viewport.slice(output.lines)
        normalized = normalized_highlights(highlights)

        curr = {
          top: viewport.top,
          height: viewport.height,
          lines: lines,
          highlights: normalized,
        }
        draw_output_lines(lines, viewport: viewport, highlights: normalized)
        @last_output_state = curr
      end

      def render_input_field(field)
        state = input_field_state(field)
        return if state == @last_input_state

        @last_input_state = state
        queue_ansi_segments_line(
          row: screen.input_rect.row,
          col: screen.input_rect.col,
          width: screen.input_rect.cols,
          segments: field_segments(
            field,
            base_role: :input,
            suggestion_role: :input_suggestion,
            region_role: :region,
          ),
          fill_role: :input,
        )
      end

      def render_pager_field(...)
        @legacy.render_pager_field(...)
      end

      def render_popup(...)
        @legacy.render_popup(...)
      end

      def render_prompt_popup(...)
        @legacy.render_prompt_popup(...)
      end

      def render_alert(alert)
        state = [
          alert&.message,
          alert&.role,
          alert&.details,
          screen.alert_rect.row,
          screen.alert_rect.cols,
        ]
        return if state == @last_alert_state

        @last_alert_state = state
        text = alert ? alert.format : ""
        spec = merged_role_spec(:alert, alert ? alert.role : :alert)

        queue_ansi_line(
          row: screen.alert_rect.row,
          col: screen.alert_rect.col,
          width: screen.alert_rect.cols,
          text: text,
          spec: spec,
        )
      end

      def begin_frame
        @pending_ansi_draws = []
      end

      def finish_frame
        flush_ansi_draws unless @pending_ansi_draws.empty?
      end

      def restore_cursor(field)
        rect = screen.input_rect
        x = field.cursor_x.to_i.clamp(0, [rect.cols - 1, 0].max)
        queue_ansi_cursor(row: rect.row, col: rect.col + x)
      end

      def sync_backgrounds!
        @legacy.sync_backgrounds!
      end

      private

      def queue_ansi_cursor(row:, col:)
        @pending_ansi_draws << {
          type: :cursor,
          row: row,
          col: col,
        }
      end

      def draw_output_lines(lines, viewport:, highlights: nil)
        rect = screen.output_rect

        rect.rows.times do |y|
          line = lines[y].to_s
          abs_line = viewport.top + y
          ranges = highlight_ranges_for_line(highlights, abs_line)

          queue_ansi_segments_line(
            row: rect.row + y,
            col: rect.col,
            width: rect.cols,
            segments: output_segments(line, ranges: ranges),
            fill_role: :output,
          )
        end
      end

      def field_segments(field, base_role:, suggestion_role: :input_suggestion, region_role: :region)
        buf = field.buffer
        text = buf.text.to_s
        segments = [{ text: field.prompt_text.to_s, role: base_role }]

        region =
          if buf.respond_to?(:region_range)
            buf.region_range
          end

        if region && region.begin < region.end
          max = text.length
          s = region.begin.clamp(0, max)
          e = region.end.clamp(0, max)

          segments << { text: text[0...s].to_s, role: base_role }
          segments << { text: text[s...e].to_s, role: region_role }
          segments << { text: text[e..].to_s, role: base_role }
        else
          segments << { text: text, role: base_role }
        end

        suffix = buf.virtual_suffix.to_s
        segments << { text: suffix, role: suggestion_role } unless suffix.empty?

        segments.reject { |seg| seg[:text].empty? }
      end

      def output_segments(line, ranges:)
        plain = Fatty::Ansi.plain_text(line.to_s)
        base_segments = []

        Fatty::Ansi.segment(line.to_s).each do |text, style|
          base_segments << {
            text: text.to_s,
            role: :output,
            style: style,
          }
        end

        apply_highlight_ranges_to_segments(base_segments, plain:, ranges:)
      end

      def apply_highlight_ranges_to_segments(segments, plain:, ranges:)
        ranges = Array(ranges).sort_by(&:first)
        return segments if ranges.empty?

        out = []
        pos = 0

        segments.each do |seg|
          text = seg[:text].to_s
          seg_start = pos
          seg_end = pos + text.length
          cursor = 0

          ranges.each do |from, to, highlight_role|
            from = from.to_i
            to = to.to_i
            next if to <= seg_start || from >= seg_end

            local_from = [from - seg_start, cursor].max
            local_to = [to - seg_start, text.length].min

            if local_from > cursor
              out << seg.merge(text: text[cursor...local_from].to_s)
            end

            out << {
              text: text[local_from...local_to].to_s,
              role: highlight_role == :secondary ? :match_other : :match_current,
            }

            cursor = local_to
          end

          if cursor < text.length
            out << seg.merge(text: text[cursor..].to_s)
          end

          pos = seg_end
        end

        out.reject { |seg| seg[:text].empty? }
      end
    end

    def queue_ansi_segments_line(row:, col:, width:, segments:, fill_role: :output)
      @pending_ansi_draws << {
        type: :segments_line,
        row: row,
        col: col,
        width: width,
        segments: segments,
        fill_role: fill_role,
      }
      nil
    end

    def queue_ansi_line(row:, col:, width:, text:, role: nil, spec: nil)
      @pending_ansi_draws << {
        row: row,
        col: col,
        width: width,
        text: text,
        role: role,
        spec: spec,
      }
    end

    def queue_ansi_rect(row:, col:, width:, height:, role:)
      return if height <= 0 || width <= 0

      height.times do |i|
        queue_ansi_line(
          row: row + i,
          col: col,
          width: width,
          text: " " * width,
          role: role,
        )
      end
      nil
    end

    def flush_ansi_draws
      Fatty.debug("flush_ansi_draws pending_count=#{@pending_ansi_draws.length}", tag: :render)

      palette = @palette || context.palette

      @pending_ansi_draws.each do |draw|
        case draw[:type]
        when :cursor
          @ansi_renderer.write_ansi("\e[#{draw[:row] + 1};#{draw[:col] + 1}H")
        when :segments_line
          @ansi_renderer.render_segments_line(
            row: draw[:row],
            col: draw[:col],
            width: draw[:width],
            segments: draw[:segments],
            palette: palette,
            fill_role: draw[:fill_role] || :output,
          )
        else
          if draw[:spec]
            @ansi_renderer.render_line_spec(
              row: draw[:row],
              col: draw[:col],
              width: draw[:width],
              text: draw[:text],
              spec: draw[:spec],
            )
          else
            @ansi_renderer.render_line(
              row: draw[:row],
              col: draw[:col],
              width: draw[:width],
              text: draw[:text],
              role: draw[:role],
              palette: palette,
            )
          end
        end
      end
      @pending_ansi_draws.clear
      nil
    end
  end
end
