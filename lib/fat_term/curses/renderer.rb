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
        state = [
          viewport.top,
          viewport.height,
          lines.map(&:dup),
          normalized_highlights(highlights),
        ]

        if state != @last_output_state
          @last_output_state = state
          draw_output(output, viewport: viewport, highlights: highlights)
        end
        nil
      end

      def draw_output(output, viewport:, highlights: nil)
        win = context.output_win
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)
        hi_attr = pair_attr(:search_highlight, fallback: ::Curses::A_REVERSE)
        hi2_attr = pair_attr(:search_highlight_secondary, fallback: hi_attr)
        win.attrset(base_attr)
        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase

        lines = viewport.slice(output.lines)
        lines.each_with_index do |line, y|
          abs_line = viewport.top + y
          ranges = highlight_ranges_for_line(highlights, abs_line)
          # Convert [from,to,role] → [from,to,attr]
          ranges =
            Array(ranges).map do |from, to, role|
            attr =
              case role
              when :secondary then hi2_attr
              else hi_attr # :primary (or nil)
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
        end
        stage_window(win)
        nil
      end

      def render_status(text, role: :status_info)
        state = [text.to_s, role]
        return if state == @last_status_state

        @last_status_state = state

        win = context.status_win
        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)

        win.erase
        win.setpos(0, 0)
        win.attrset(attr)
        win.bkgdset(attr) if win.respond_to?(:bkgdset)

        msg = text.to_s.tr("\r\n", " ")
        win.addstr(msg.ljust(cols)[0, cols])
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
        win.attrset(base_attr)
        win.erase

        win.setpos(0, 0)
        win.addstr(" " * win.maxx)
        win.setpos(0, 0)
        win.addstr(field.prompt_text)

        text = buf.text.to_s

        if region && region.begin < region.end
          # Render the buffer in three parts, before region, region, and
          # after region.
          max = text.length
          s = region.begin.clamp(0, max)
          e = region.end.clamp(0, max)

          before = text[0...s].to_s
          mid    = text[s...e].to_s
          after  = text[e..].to_s

          win.addstr(before)
          region_attr =
            pair_attr(
              :region,
              fallback: ::Curses::A_REVERSE,
            )
          win.attron(region_attr) { win.addstr(mid) }
          win.addstr(after)
        else
          win.addstr(text)
        end

        suffix = buf.virtual_suffix.to_s
        unless suffix.empty?
          suggestion_attr = pair_attr(:input_suggestion, fallback: 0) | ::Curses::A_DIM
          win.attron(suggestion_attr) { win.addstr(suffix) }
        end

        win.setpos(0, field.cursor_x)
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

        win.setpos(row, 0)
        win.attrset(attr)
        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.clrtoeol

        prompt = field.prompt_text.to_s
        buf_text = field.buffer.text.to_s
        text = (prompt + buf_text).tr("\r\n", "")

        win.addstr(text.ljust(cols)[0, cols])
        stage_window(win)
        nil
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state
        win = context.alert_win
        win.erase
        win.setpos(0, 0)
        win.clrtoeol

        if alert.nil?
          # Always draw a bar so the "panel" is visible even when empty.
          if ::Curses.has_colors?
            win.attron(pair_attr(:status_info, fallback: ::Curses::A_REVERSE)) { win.addstr(" ".ljust(@screen.cols)) }
          else
            win.attron(::Curses::A_REVERSE) { win.addstr(" ".ljust(@screen.cols)) }
          end
        else
          attr = alert_attr(alert)
          win.attron(attr) do
            text = format_alert(alert)
            win.addstr(text.ljust(@screen.cols))
          end
        end
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

        width = win.maxx
        height = win.maxy
        win.erase

        frame_attr = pair_attr(:popup_frame, fallback: ::Curses::A_NORMAL)
        win.attron(frame_attr) do
          draw_popup_frame(win, width: width, height: height)
        end

        inner_h = height - 2
        inner_w = width - 2
        inner = win.derwin(inner_h, inner_w, 1, 1)
        inner.erase

        # title (still on the frame)
        if session.title
          win.setpos(0, 2)
          win.addstr(" #{session.title} ")
        end

        # list area: inner_h-1 lines (last inner line is input)
        list_h = inner_h - 1
        list_w = inner_w

        results_attr  = pair_attr(:popup, fallback: ::Curses::A_NORMAL)
        input_attr    = pair_attr(:popup_input, fallback: ::Curses::A_REVERSE)
        selected_attr = pair_attr(:popup_selection, fallback: ::Curses::A_REVERSE)

        items = session.filtered
        sel   = session.selected
        start = session.scroll_start(list_h: list_h)

        inner.attron(results_attr) do
          (0...list_h).each do |i|
            idx = start + i
            is_sel = (idx == sel)
            row_attr = is_sel ? selected_attr : results_attr
            inner.attrset(row_attr)

            inner.setpos(i, 0)
            inner.addstr(" " * list_w)
            inner.setpos(i, 0)

            next if idx >= items.length

            gutter = idx == sel ? POPUP_SELECTED_GUTTER : POPUP_UNSELECTED_GUTTER
            s = items[idx].to_s
            s = s[0, list_w - gutter.length]
            row = gutter + s

            inner.addstr(row.ljust(list_w))
          end
        end

        inner.attron(input_attr) do
          # input line at bottom (inside inner)
          inner.setpos(inner_h - 1, 0)
          inner.addstr(" " * list_w)
          inner.setpos(inner_h - 1, 0)

          prompt = session.field.prompt_text.to_s
          text   = session.field.buffer.text.to_s

          line = (prompt + text)[0, list_w]
          inner.addstr(line.ljust(list_w))
        end

        # cursor: move in outer window coords
        cursor_in_inner = session.field.cursor_x.clamp(0, list_w - 1)
        win.setpos(1 + (inner_h - 1), 1 + cursor_in_inner)

        stage_window(inner)
        stage_window(win)
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
          session.filtered.object_id,
          session.filtered.length,
          session.filtered.first&.to_s,
          session.filtered.last&.to_s,
          session.selected,
          session.field.buffer.text.to_s,
          session.field.cursor_x
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
