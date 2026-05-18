# lib/fatty/renderer/curses.rb

module Fatty
  class Renderer
    class Curses < Fatty::Renderer
      include Fatty::Curses::WindowStyling

      def initialize(...)
        super
        @legacy = Fatty::Curses::Renderer.new(
          screen: screen,
          context: context,
        )
      end

      def render_status(text, role: :status_info)
        state = [renderable_text(text), role]
        return if state == @last_status_state

        @last_status_state = state

        win = context.status_win
        return unless win

        cols = win.respond_to?(:maxx) ? win.maxx : screen.cols
        base_attr = pair_attr(role, fallback: ::Curses::A_REVERSE)
        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase
        win.setpos(0, 0)

        remaining = cols
        renderable_segments(text, role: role).each do |segment|
          break if remaining <= 0

          seg_text = Fatty::Ansi.strip(segment[:text].to_s).tr("\r\n", " ")
          seg_text = Fatty::Ansi.truncate_visible(seg_text, remaining)
          next if seg_text.empty?

          attr = pair_attr(segment[:role], fallback: base_attr)
          win.attrset(attr)
          win.addstr(seg_text)

          remaining -= Fatty::Ansi.visible_length(seg_text)
        end
        if remaining.positive?
          win.attrset(base_attr)
          win.addstr(" " * remaining)
        end
        stage_window(win)
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

        prev = @last_output_state

        if prev && can_incrementally_scroll_output?(prev, curr)
          scroll_output_window_delta!(prev: prev, curr: curr)
        else
          draw_output_lines(lines, viewport: viewport, highlights: normalized)
        end

        @last_output_state = curr
        nil
      end

      def render_input_field(field, role: :input)
        state = input_field_state(field)
        return if state == @last_input_state

        @last_input_state = state

        win = context.input_win
        return unless win

        width = win.respond_to?(:maxx) ? win.maxx : screen.cols
        base_attr = pair_attr(role, fallback: ::Curses::A_NORMAL)
        region_attr = pair_attr(:region, fallback: ::Curses::A_REVERSE)
        suggestion_attr = pair_attr(:input_suggestion, fallback: base_attr)

        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(base_attr)

        render_field_into(
          win: win,
          field: field,
          row: 0,
          width: width,
          base_attr: base_attr,
          region_attr: region_attr,
          suggestion_attr: suggestion_attr,
        )
        cursor_x = field.cursor_x.to_i.clamp(0, [width - 1, 0].max)
        win.setpos(0, cursor_x)
        stage_window(win)
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state

        win = context.alert_win
        return unless win

        text = alert ? alert.format : ""
        text = Fatty::Ansi.strip(text)
        role = alert ? alert.role : :alert
        attr = pair_attr(role, fallback: pair_attr(:alert, fallback: ::Curses::A_REVERSE))
        cols = win.respond_to?(:maxx) ? win.maxx : screen.alert_rect.cols

        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        win.setpos(0, 0)
        win.addstr(text.ljust(cols)[0, cols])

        stage_window(win)
      end

      def begin_frame
        @legacy.begin_frame
      end

      def finish_frame
        @legacy.finish_frame
      end

      def restore_cursor(...)
        @legacy.restore_cursor(...)
      end

      # Restore cursor into the output window at a specific *output-win* row.
      # `row:` is 0..(screen.output_rect.rows-1), NOT an absolute screen row.
      def restore_output_cursor(field, row:)
        win = context.output_win
        cols = @screen.cols

        x = field.cursor_x.to_i
        x = x.clamp(0, [cols - 1, 0].max)

        if context.truecolor
          row0 = @screen.output_rect.row
          col0 = @screen.output_rect.col
          cols = @screen.output_rect.cols

          @pending_ansi_draws << {
            type: :cursor,
            row: row0 + row,
            col: col0 + x.clamp(0, [cols - 1, 0].max),
          }
          return
        end
        @frame_touched = true
        win.setpos(row, x)
        stage_window(win)
      end

      private

      def available_colors
        ::Curses.colors
      end

      def after_apply_theme!
        context.apply_palette_to_curses!(palette)
      end

      def can_incrementally_scroll_output?(prev, curr)
        delta = curr[:top] - prev[:top]
        output_rows =
          if context.output_win.respond_to?(:maxy)
            context.output_win.maxy
          else
            @screen.output_rect.rows
          end

        curr[:height] == output_rows &&
          curr[:height] == prev[:height] &&
          curr[:highlights] == prev[:highlights] &&
          delta != 0 && delta.abs < curr[:height]
      end

      def scroll_output_window_delta!(prev:, curr:)
        Fatty.debug("calling scroll_output_window_delta!", tag: :scrolling)
        win = context.output_win
        delta = curr[:top] - prev[:top]
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)

        win.attrset(base_attr)
        win.scrl(delta)

        if delta > 0
          start_y = curr[:height] - delta
          start_y = 0 if start_y < 0

          (start_y...curr[:height]).each do |y|
            line = curr[:lines][y]
            abs_line = curr[:top] + y
            draw_output_row(
              win,
              line: line,
              y: y,
              abs_line: abs_line,
              highlights: curr[:highlights],
            )
          end
        else
          count = -delta
          count = curr[:height] if count > curr[:height]
          (0...count).each do |y|
            line = curr[:lines][y]
            abs_line = curr[:top] + y
            draw_output_row(
              win,
              line: line,
              y: y,
              abs_line: abs_line,
              highlights: curr[:highlights],
            )
          end
        end
        stage_window(win)
      end

      def draw_output_lines(lines, viewport:, highlights: nil)
        win = context.output_win
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)

        win.attrset(base_attr)
        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase

        lines.each_with_index do |line, y|
          abs_line = viewport.top + y
          draw_output_row(
            win,
            line: line,
            y: y,
            abs_line: abs_line,
            highlights: highlights,
          )
        end
        stage_window(win)
      end

      def draw_output_row(win, line:, y:, abs_line:, highlights:)
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)
        hi_attr = pair_attr(:match_current, fallback: ::Curses::A_REVERSE)
        hi2_attr = pair_attr(:match_other, fallback: hi_attr)

        semantic_ranges = highlight_ranges_for_line(highlights, abs_line)
        win.setpos(y, 0)
        win.attrset(base_attr)
        curses_ranges =
          Array(semantic_ranges).map do |from, to, role|
          attr =
            case role
            when :secondary then hi2_attr
            else hi_attr
            end

          [from.to_i, to.to_i, attr]
        end
        plain = Fatty::Ansi.plain_text(line.to_s)
        slices = build_line_slices(plain, ranges: curses_ranges) do |_style|
          base_attr
        end
        render_slices(win, slices)
        win.clrtoeol
      end

      # Build a draw plan for a single output line.
      #
      # Returns an array of [attr, text] slices.
      #
      # Yields each ANSI style hash and expects an attr back for non-highlight text.
      # ranges are plain-text indices:
      #   [[from, to, attr], ...]
      #
      # Yields each ANSI style hash and expects an attr back for non-highlight text.
      def build_line_slices(line, ranges:)
        slices = []
        return slices if line.nil?

        ranges = Array(ranges)
        pos = 0
        ri = 0

        Fatty::Ansi.segment(line).each do |text, style|
          text = text.to_s
          seg_attr = yield(style)

          seg_from = pos
          seg_to   = pos + text.length

          # advance past ranges that end before this segment
          ri += 1 while ri < ranges.length && ranges[ri][1] <= seg_from

          if ri >= ranges.length
            emit_slice(slices, seg_attr, text)
            pos = seg_to
            next
          end

          cursor = 0
          while cursor < text.length
            gpos = seg_from + cursor
            r = (ri < ranges.length ? ranges[ri] : nil)

            if r && gpos < r[0]
              # normal until next range starts
              upto = [r[0], seg_to].min - seg_from
              upto = text.length if upto > text.length
              emit_slice(slices, seg_attr, text.slice(cursor, upto - cursor).to_s)
              cursor = upto
            elsif r && gpos >= r[0] && gpos < r[1]
              # highlighted portion
              upto = [r[1], seg_to].min - seg_from
              upto = text.length if upto > text.length
              emit_slice(slices, r[2], text.slice(cursor, upto - cursor).to_s)
              cursor = upto

              # consume this range if we reached/passed its end
              if ri < ranges.length && ranges[ri][1] <= (seg_from + cursor)
                ri += 1
              end
            else
              # no active range; remainder is normal
              emit_slice(slices, seg_attr, text.slice(cursor, text.length - cursor).to_s)
              cursor = text.length
            end
          end
          pos = seg_to
        end
        slices
      end

      def render_slices(win, slices)
        Array(slices).each do |attr, text|
          win.attrset(attr)
          win.addstr(text.to_s)
        end
      end

      def emit_slice(slices, attr, text)
        return if text.nil? || text.empty?

        last = slices[-1]
        if last && last[0] == attr
          last[1] << text
        else
          slices << [attr, text.dup]
        end
      end

      def stage_window(win)
        win.noutrefresh
        @frame_touched = true
      end

      def render_field_into(win:, field:, row:, width:, base_attr:, region_attr:, suggestion_attr:)
        buf = field.buffer
        region =
          if buf.respond_to?(:region_range)
            buf.region_range
          end

        win.attrset(base_attr)
        win.setpos(row, 0)
        win.addstr(" " * width)
        win.setpos(row, 0)
        win.addstr(field.prompt_text.to_s)

        text = buf.text.to_s

        if region && region.begin < region.end
          max = text.length
          s = region.begin.clamp(0, max)
          e = region.end.clamp(0, max)

          before = text[0...s].to_s
          mid    = text[s...e].to_s
          after  = text[e..].to_s

          win.attrset(base_attr)
          win.addstr(before)

          win.attrset(region_attr)
          win.addstr(mid)

          win.attrset(base_attr)
          win.addstr(after)
        else
          win.attrset(base_attr)
          win.addstr(text)
        end

        suffix = buf.virtual_suffix.to_s
        unless suffix.empty?
          win.attrset(base_attr)
          win.attron(suggestion_attr) { win.addstr(suffix) }
        end
      end

      def draw_popup_frame(win, width:, height:)
        b = popup_border
        # top
        win.setpos(0, 0)
        win.addstr(b[:tl] + (b[:h] * (width - 2)) + b[:tr])
        # sides
        (1...(height - 1)).each do |y|
          win.setpos(y, 0)
          win.addstr(b[:v])
          win.setpos(y, width - 1)
          win.addstr(b[:v])
        end
        # bottom
        win.setpos(height - 1, 0)
        win.addstr(b[:bl] + (b[:h] * (width - 2)) + b[:br])
      end

      def render_field_into(win:, field:, row:, width:, base_attr:, region_attr:, suggestion_attr:)
        buf = field.buffer
        region =
          if buf.respond_to?(:region_range)
            buf.region_range
          end

        win.attrset(base_attr)
        win.setpos(row, 0)
        win.addstr(" " * width)
        win.setpos(row, 0)
        win.addstr(field.prompt_text.to_s)

        text = Fatty::Ansi.strip(buf.text.to_s)
        if region && region.begin < region.end
          max = text.length
          s = region.begin.clamp(0, max)
          e = region.end.clamp(0, max)

          before = text[0...s].to_s
          mid    = text[s...e].to_s
          after  = text[e..].to_s

          win.attrset(base_attr)
          win.addstr(before)

          win.attrset(region_attr)
          win.addstr(mid)

          win.attrset(base_attr)
          win.addstr(after)
        else
          win.attrset(base_attr)
          win.addstr(text)
        end

        suffix = buf.virtual_suffix.to_s
        unless suffix.empty?
          win.attrset(base_attr)
          win.attron(suggestion_attr) { win.addstr(suffix) }
        end
      end
    end
  end
end
