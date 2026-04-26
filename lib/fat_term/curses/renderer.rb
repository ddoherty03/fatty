# frozen_string_literal: true

module FatTerm
  module Curses
    # The Curses Renderer is responsible for drawing FatTerm views using curses.
    #
    # Renderer provides the drawing API used by View objects.  Views never call
    # curses directly; instead, they request drawing operations from the Renderer.
    #
    # Responsibilities:
    #   - translate high-level draw requests into curses window operations
    #   - apply colors, attributes, and cursor placement
    #   - respect layout information provided by FatTerm::Screen
    #   - refresh windows at frame boundaries
    #
    # Renderer deliberately does NOT:
    #   - read keyboard or mouse input
    #   - decode raw key sequences
    #   - manage session state
    #   - decide which views should be rendered
    #
    # In the architecture:
    #
    #   Session  → owns state
    #   View     → decides *what* to draw
    #   Renderer → decides *how* to draw
    #   Context  → owns curses and window lifecycle
    #
    # Terminal coordinates rendering by collecting Views from active Sessions,
    # ordering them by z-index, and invoking Renderer methods during each frame.
    #
    # Renderer is backend-specific.  Other renderers may exist in the future
    # (e.g., ANSI, headless, test), but Views and Sessions remain unchanged.
    class Renderer
      attr_reader :context

      DETAIL_ORDER = %i[terminal key ctrl meta shift].freeze

      POPUP_BORDER = {
        tl: "┌",
        tr: "┐",
        bl: "└",
        br: "┘",
        h: "─",
        v: "│",
      }.freeze

      POPUP_SELECTED_GUTTER = "▶ "
      POPUP_UNSELECTED_GUTTER = "  "

      def initialize(context:, screen:)
        @context = context
        @screen = screen
        reset_frame_cache
      end

      def screen=(screen)
        @screen = screen
        reset_frame_cache
      end

      def begin_frame
        @frame_touched = false
        nil
      end

      def finish_frame
        if @frame_touched
          if ::Curses.respond_to?(:doupdate)
            ::Curses.doupdate
          end
        end
        nil
      end

      def render(output:, input_field:, alert:, viewport:)
        render_output(output, viewport:)
        render_input_field(input_field)
        render_alert(alert)
        restore_cursor(input_field)
      end

      def restore_cursor(field)
        win = context.input_win
        win.setpos(0, field.cursor_x)
        stage_window(win)
        nil
      end

      # Restore cursor into the output window at a specific *output-win* row.
      # `row:` is 0..(screen.output_rect.rows-1), NOT an absolute screen row.
      def restore_output_cursor(field, row:)
        win = context.output_win
        cols = @screen.cols

        x = field.cursor_x.to_i
        x = x.clamp(0, [cols - 1, 0].max)

        win.setpos(row, x)
        stage_window(win)
        nil
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
          draw_output_lines(lines, viewport: viewport, highlights: highlights)
        end

        @last_output_state = curr
        nil
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
        delta != 0 &&
          delta.abs < curr[:height]
      end

      def draw_output_lines(lines, viewport:, highlights: nil)
        FatTerm.debug("calling draw_output_lines")
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
        nil
      end

      def draw_output_row(win, line:, y:, abs_line:, highlights:)
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)
        hi_attr = pair_attr(:search_highlight, fallback: ::Curses::A_REVERSE)
        hi2_attr = pair_attr(:search_highlight_secondary, fallback: hi_attr)

        ranges = highlight_ranges_for_line(highlights, abs_line)
        ranges =
          Array(ranges).map do |from, to, role|
          attr =
            case role
            when :secondary then hi2_attr
            else hi_attr
            end
          [from.to_i, to.to_i, attr]
        end

        win.setpos(y, 0)
        win.attrset(base_attr)
        slices = build_line_slices(line, ranges: ranges) do |style|
          context.ansi_attr(style, fallback_role: :output)
        end
        render_slices(win, slices)
        win.clrtoeol
        nil
      end

      def scroll_output_window_delta!(prev:, curr:)
        FatTerm.debug("calling scroll_output_window_delta!", tag: :scrolling)
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
        nil
      end

      def render_status(text, role: :status_info)
        msg = text.to_s.tr("\r\n", " ")
        state = [msg, role]
        return if state == @last_status_state

        @last_status_state = state

        win = context.status_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)

        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        win.setpos(0, 0)
        win.addstr(msg.ljust(cols)[0, cols])

        stage_window(win)
        nil
      end

      def render_status(text, role: :status_info)
        msg = text.to_s.tr("\r\n", " ")
        state = [msg, role]
        return if state == @last_status_state

        @last_status_state = state

        win = context.status_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)

        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        win.setpos(0, 0)

        slices = build_line_slices(msg, ranges: []) do |style|
          context.ansi_attr(style, fallback_role: role)
        end

        used = 0
        slices.each do |slice_attr, slice_text|
          break if used >= cols

          visible = slice_text.to_s
          remaining = cols - used
          clipped = visible[0, remaining]

          win.attrset(slice_attr)
          win.addstr(clipped)

          used += clipped.length
        end

        if used < cols
          win.attrset(attr)
          win.addstr(" " * (cols - used))
        end

        stage_window(win)
        nil
      end

      def render_input_field(field)
        buf = field.buffer
        region =
          if buf.respond_to?(:region_range)
            buf.region_range
          end
        state = field.snapshot_input_state
        return if state == @last_input_state

        @last_input_state = state

        win = context.input_win
        base_attr = pair_attr(:input, fallback: ::Curses::A_NORMAL)
        region_attr = pair_attr(:region, fallback: ::Curses::A_REVERSE)
        suggestion_attr = pair_attr(:input_suggestion, fallback: 0) | ::Curses::A_DIM

        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(base_attr)

        width = win.respond_to?(:maxx) ? win.maxx : @screen.cols

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
        nil
      end

      # Render an InputField-like status line inside the output window.
      #
      # Used for pager mode ("--More--" etc.). It intentionally does not move
      # the cursor; ShellSession decides whether to show a cursor in paging
      # vs input mode.
      def render_pager_field(field, row:, role: :status_info)
        state = [field.prompt_text.to_s, field.buffer.text.to_s, row, role]
        return if state == @last_pager_field_state

        @last_pager_field_state = state

        win = context.output_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)

        prompt = field.prompt_text.to_s
        buf_text = field.buffer.text.to_s
        text = (prompt + buf_text).tr("\r\n", "")

        visible = FatTerm::Ansi.plain_text(text)
        line = visible[0, cols].ljust(cols)

        win.setpos(row, 0)
        win.attrset(attr)
        win.addstr(line)

        stage_window(win)
        nil
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state
        win = context.alert_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols

        attr =
          if alert.nil?
            pair_attr(:status_info, fallback: ::Curses::A_REVERSE)
          else
            alert_attr(alert)
          end

        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        win.setpos(0, 0)

        text =
          if alert.nil?
            ""
          else
            format_alert(alert)
          end

        win.addstr(text.ljust(cols)[0, cols])

        stage_window(win)
        nil
      end

      def pair_attr(role, fallback:)
        return fallback unless ::Curses.has_colors?

        ::Curses.color_pair(FatTerm::Colors::Pairs::ROLE_TO_PAIR.fetch(role))
      end

      def render_popup(session:)
        state = popup_state(session)
        return if state == @last_popup_state

        @last_popup_state = state

        win = session.win
        return unless win

        begin
          width = win.maxx
          height = win.maxy
        rescue RuntimeError
          return
        end

        win.erase

        frame_attr = pair_attr(:popup_frame, fallback: ::Curses::A_NORMAL)
        win.attron(frame_attr) do
          draw_popup_frame(win, width: width, height: height)
        end

        inner_h = height - 2
        inner_w = width - 2
        return if inner_h <= 0 || inner_w <= 0

        inner = win.derwin(inner_h, inner_w, 1, 1)
        inner.erase

        if session.title
          win.setpos(0, 2)
          win.addstr(" #{session.title} ")
        end

        results_attr = pair_attr(:popup, fallback: ::Curses::A_NORMAL)
        input_attr = pair_attr(:popup_input, fallback: ::Curses::A_REVERSE)
        selected_attr = pair_attr(:popup_selection, fallback: ::Curses::A_REVERSE)
        counts_attr =
          begin
            pair_attr(:popup_counts, fallback: results_attr)
          rescue KeyError
            results_attr
          end

        row = 0
        if session.message && !session.message.empty?
          inner.attrset(results_attr)
          inner.setpos(row, 0)
          line = session.message.to_s[0, inner_w]
          inner.addstr(line.ljust(inner_w))
          row += 1
        end

        input_row = inner_h - 1
        counts_row = inner_h - 2
        list_row = row
        list_h = counts_row - list_row
        list_h = 1 if list_h < 1
        list_w = inner_w

        items = session.displayed
        sel = session.selected
        start = session.scroll_start(list_h: list_h)

        (0...list_h).each do |i|
          idx = start + i
          is_sel = (idx == sel)
          row_attr = is_sel ? selected_attr : results_attr

          inner.attrset(row_attr)
          inner.setpos(list_row + i, 0)
          inner.addstr(" " * list_w)
          inner.setpos(list_row + i, 0)

          next if idx >= items.length

          item = items[idx]
          gutter = session.gutter_for(item: item, selected: is_sel)
          avail = [list_w - gutter.length, 0].max
          s = item.to_s[0, avail]
          line = (gutter + s)[0, list_w]

          inner.addstr(line.ljust(list_w))
        end

        counts = session.counts
        counts_text =
          "#{counts[:total]} total · " \
          "#{counts[:selected]} selected · " \
          "#{counts[:matching]} matching · " \
          "#{counts[:showing]} showing"

        if counts_row >= 0
          inner.attrset(counts_attr)
          inner.setpos(counts_row, 0)
          inner.addstr(counts_text[0, inner_w].to_s.ljust(inner_w))
        end

        region_attr = pair_attr(:region, fallback: ::Curses::A_REVERSE)
        suggestion_attr = pair_attr(:input_suggestion, fallback: 0) | ::Curses::A_DIM
        render_field_into(
          win: inner,
          field: session.field,
          row: input_row,
          width: list_w,
          base_attr: input_attr,
          region_attr: region_attr,
          suggestion_attr: suggestion_attr,
        )

        cursor_in_inner = session.field.cursor_x.clamp(0, [list_w - 1, 0].max)
        win.setpos(1 + input_row, 1 + cursor_in_inner)

        stage_window(inner)
        stage_window(win)
        nil
      end

      def render_prompt_popup(session:)
        win = session.win
        return unless win

        begin
          width = win.maxx
          height = win.maxy
          win.erase

          frame_attr = pair_attr(:popup_frame, fallback: ::Curses::A_NORMAL)
          win.attron(frame_attr) do
          draw_popup_frame(win, width: width, height: height)
        end

          inner_h = height - 2
          inner_w = width - 2
          return nil if inner_h <= 0 || inner_w <= 0

          inner = win.derwin(inner_h, inner_w, 1, 1)
          inner.erase

          if session.title
            win.setpos(0, 2)
            win.addstr(" #{session.title} ")
          end

          text_attr  = pair_attr(:popup, fallback: ::Curses::A_NORMAL)
          input_attr = pair_attr(:popup_input, fallback: ::Curses::A_REVERSE)

          row = 0

          if session.message && !session.message.empty?
            inner.attron(text_attr) do
              inner.setpos(row, 0)
              line = session.message.to_s[0, inner_w]
              inner.addstr(line.ljust(inner_w))
            end
            row += 1
          end

          region_attr = pair_attr(:region, fallback: ::Curses::A_REVERSE)
          suggestion_attr = pair_attr(:input_suggestion, fallback: 0) | ::Curses::A_DIM
          render_field_into(
            win: inner,
            field: session.field,
            row: row,
            width: inner_w,
            base_attr: input_attr,
            region_attr: region_attr,
            suggestion_attr: suggestion_attr,
          )

          cursor_in_inner = session.field.cursor_x.clamp(0, [inner_w - 1, 0].max)
          win.setpos(1 + row, 1 + cursor_in_inner)

          stage_window(inner)
          stage_window(win)
        rescue RuntimeError => e
          raise unless e.message.include?("closed window") || e.message.include?("already closed window")
          nil
        end

        nil
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

        nil
      end

      def apply_theme!(theme)
        context.apply_theme!(theme)
        reset_frame_cache
      end

      def invalidate!
        reset_frame_cache
        self
      end

      private

      def stage_window(win)
        if win.respond_to?(:noutrefresh)
          win.noutrefresh
          @frame_touched = true
        else
          win.refresh
        end
        nil
      end

      def reset_frame_cache
        @last_output_state = nil
        @last_input_state = nil
        @last_alert_state = nil
        @last_pager_field_state = nil
        @last_popup_state = nil
        @frame_touched = false
        @last_status_state = nil
        nil
      end

      def normalized_highlights(highlights)
        return if highlights.nil?

        highlights.each_with_object({}) do |(line_no, ranges), out|
          out[line_no] =
            Array(ranges).map do |r|
            if r.is_a?(Hash)
              [r[:from].to_i, r[:to].to_i, (r[:role] || :primary).to_sym]
            else
              [r[0].to_i, r[1].to_i, (r[2] || :primary).to_sym]
            end
          end
        end
      end

      def alert_state(alert)
        if alert
          [alert.level, format_alert(alert), alert_attr(alert)]
        else
          [:empty, @screen.cols]
        end
      end

      def popup_state(session)
        [
          session.displayed.map(&:to_s),
          session.selected,
          session.field.buffer.text.to_s,
          session.field.cursor_x,
          session.selected_labels.sort,
          session.counts,
        ]
      end

      def highlight_ranges_for_line(highlights, abs_line)
        return [] unless highlights

        raw = highlights[abs_line]
        return [] unless raw

        # Accept any of:
        #   [[from,to], ...]
        #   [[from,to,:primary], [from,to,:secondary], ...]
        #   [{from:, to:, role:}, ...]
        ranges =
          Array(raw).map do |r|
          if r.is_a?(Hash)
            [r[:from].to_i, r[:to].to_i, (r[:role] || :primary).to_sym]
          else
            a = r[0].to_i
            b = r[1].to_i
            role = (r[2] || :primary).to_sym
            [a, b, role]
          end
        end

        ranges.sort_by!(&:first)
        ranges
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

        FatTerm::Ansi.segment(line).each do |text, style|
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

      def emit_slice(slices, attr, text)
        return if text.nil? || text.empty?

        last = slices[-1]
        if last && last[0] == attr
          last[1] << text
        else
          slices << [attr, text.dup]
        end
      end

      def render_slices(win, slices)
        Array(slices).each do |attr, text|
          win.attrset(attr)
          win.addstr(text.to_s)
        end
      end

      def alert_attr(alert)
        return ::Curses::A_REVERSE unless ::Curses.has_colors?

        role =
          case alert.level
          when :error   then :status_error
          when :warning then :status_warn
          else               :status_info
          end
        pair_attr(role, fallback: ::Curses::A_REVERSE)
      end

      def format_alert(alert)
        icon =
          case alert.level
          when :warning then "⚠"
          when :error   then "✖"
          else               "ℹ"
          end

        msg = alert.message.to_s

        details_str = ""
        if alert.details.respond_to?(:empty?) ? !alert.details.empty? : !!alert.details
          if alert.details.is_a?(Hash)
            details_str =
              " (" +
              DETAIL_ORDER.filter_map { |k| "#{k}=#{alert.details[k]}" if alert.details.key?(k) }.join(" ") +
              ")"
          else
            details_str = " (#{alert.details})"
          end
        end
        "  #{icon} #{msg}#{details_str}"
      end

      def draw_popup_frame(win, width:, height:)
        b = POPUP_BORDER
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
    end
  end
end
