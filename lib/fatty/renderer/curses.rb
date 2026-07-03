# frozen_string_literal: true

# lib/fatty/renderer/curses.rb

module Fatty
  class Renderer
    class Curses < Fatty::Renderer
      include Fatty::Curses::WindowStyling

      def initialize(...)
        super
      end

      def render_status(status_session)
        state = status_state(status_session)
        return if state == @last_status_state

        @last_status_state = state
        draw_status_lines(status_session)
      end

      def render_output(output_session, viewport: output_session.viewport)
        outbuf = output_session.output
        lines = viewport.slice(outbuf.lines)
        normalized = normalized_highlights(output_session.highlights)

        curr = output_state(output_session, viewport: viewport)
        prev = @last_output_state

        if prev &&
           !ansi_lines?(lines) &&
           output_session.incrementally_scrollable_from?(prev, curr)
          scroll_output_window_delta!(
            delta: output_session.scroll_delta_from(prev, curr),
            lines: lines,
            viewport: viewport,
            highlights: normalized,
          )
        else
          draw_output_lines(lines, viewport: viewport, highlights: normalized)
        end
        @last_output_state = curr
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
          base_role: role,
          base_attr: base_attr,
          region_attr: region_attr,
          suggestion_attr: suggestion_attr,
        )
        cursor_x = field.cursor_x.to_i.clamp(0, [width - 1, 0].max)
        win.setpos(0, cursor_x)
        stage_window(win)
      end

      def clear_input_field
        @last_input_state = nil

        win = context.input_win
        return unless win

        attr = pair_attr(:input, fallback: ::Curses::A_NORMAL)
        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(attr)
        stage_window(win)
      end

      def render_alert(alert_session)
        state = alert_state(alert_session)
        return if state == @last_alert_state

        @last_alert_state = state

        win = context.alert_win
        return unless win

        alert = alert_session.current
        text = alert ? alert.format : ""
        role = alert ? alert_role(alert.role) : :alert_info
        base_attr = pair_attr(role, fallback: pair_attr(:alert, fallback: ::Curses::A_REVERSE))
        cols = win.respond_to?(:maxx) ? win.maxx : screen.alert_rect.cols

        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase
        win.attrset(base_attr)
        win.setpos(0, 0)

        segments = Fatty::Ansi.segment(text).map do |segment_text, style|
          {
            text: segment_text,
            role: role,
            style: style,
          }
        end

        draw_status_row(
          win,
          row: 0,
          cols: cols,
          segments: segments,
          base_attr: base_attr,
        )

        stage_window(win)
      end

      # Render an InputField-like status line.
      #
      # Used for pager mode ("--More--" etc.). It intentionally does not move
      # the cursor; ShellSession decides whether to show a cursor in paging
      # vs input mode.
      #
      # Curses uses a derived one-line window to isolate the pager/search field
      # from output_win scrolling/background effects.
      #
      # Truecolor renders the same field as an ANSI overlay at absolute coordinates,
      # so no derived window is needed there.
      def render_pager_field(field, row:, role: :pager_status)
        win = context.output_win
        return unless win

        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols
        attr = pair_attr(role, fallback: ::Curses::A_REVERSE)

        field_win = win.derwin(1, cols, row, 0)
        field_win.bkgdset(attr) if field_win.respond_to?(:bkgdset)
        field_win.erase
        field_win.attrset(attr)

        render_field_into(
          win: field_win,
          field: field,
          row: 0,
          width: cols,
          base_attr: attr,
          region_attr: pair_attr(:region, fallback: ::Curses::A_REVERSE),
          suggestion_attr: pair_attr(:input_suggestion, fallback: attr),
          base_role: role,
        )

        field_win.noutrefresh
        stage_window(win)
      ensure
        field_win&.close if field_win&.respond_to?(:close)
      end

      # Modal overlays, render_popup and render_prompt_popu are deliberately
      # not state-cached.
      #
      # They must be restaged on every frame because they are drawn on top of the
      # focused session. Even when the overlay's own state has not changed, the
      # underlying session may have redrawn the area beneath it. Skipping the overlay
      # render would let the underlying frame erase or visually punch through it.

      def render_popup(session:)
        win = session.win
        return unless win

        width = win.maxx
        height = win.maxy
        return if width < 2 || height < 2

        win.erase

        frame_attr = pair_attr(:popup_frame, fallback: ::Curses::A_NORMAL)
        popup_attr = pair_attr(:popup, fallback: ::Curses::A_NORMAL)
        input_attr = pair_attr(:popup_input, fallback: ::Curses::A_REVERSE)
        selected_attr = pair_attr(:popup_selection, fallback: ::Curses::A_REVERSE)
        counts_attr = pair_attr(:popup_counts, fallback: popup_attr)

        win.attrset(frame_attr)
        draw_popup_frame(win, width: width, height: height)

        if session.title && !session.title.empty?
          title = Fatty::Ansi.strip(session.title.to_s).tr("\r\n", " ")
          title = Fatty::Ansi.truncate_visible(" #{title} ", [width - 4, 0].max)

          unless title.empty?
            win.setpos(0, 2)
            win.addstr(title)
          end
        end
        inner_h = height - 2
        inner_w = width - 2
        return if inner_h <= 0 || inner_w <= 0

        inner = win.derwin(inner_h, inner_w, 1, 1)
        inner.bkgdset(popup_attr) if inner.respond_to?(:bkgdset)
        inner.erase

        row = 0

        if session.message && !session.message.empty?
          message = Fatty::Ansi.strip(session.message.to_s).tr("\r\n", " ")
          message = Fatty::Ansi.truncate_visible(message, inner_w)

          inner.attrset(popup_attr)
          inner.setpos(row, 0)
          inner.addstr(message.ljust(inner_w))
          row += 1
        end

        counts_present = session.counts_present?
        filter_present = session.filter_present?
        input_row =
          if filter_present
            inner_h - 1
          end
        counts_row =
          if counts_present
            filter_present ? input_row - 1 : inner_h - 1
          end
        list_row = row
        list_end =
          if counts_present
            counts_row
          elsif filter_present
            input_row
          else
            inner_h
          end
        list_h = [list_end - list_row, 0].max

        items = session.displayed
        selected = session.current
        start = session.scroll_start(list_h: list_h)

        (0...list_h).each do |offset|
          item_index = start + offset
          item_selected = item_index == selected
          attr = item_selected ? selected_attr : popup_attr

          line = ""
          if item_index < items.length
            item = items[item_index]
            gutter = session.gutter_for(item: item, selected: item_selected)
            text = Fatty::Ansi.strip(item.to_s).tr("\r\n", " ")
            available = [inner_w - Fatty::Ansi.visible_length(gutter), 0].max
            text = Fatty::Ansi.truncate_visible(text, available)
            line = Fatty::Ansi.truncate_visible(gutter + text, inner_w)
          end

          inner.attrset(attr)
          inner.setpos(list_row + offset, 0)
          inner.addstr(line.ljust(inner_w))
        end

        if counts_present && counts_row && counts_row >= 0
          counts_text = Fatty::Ansi.truncate_visible(popup_counts_text(session), inner_w)

          inner.attrset(counts_attr)
          inner.setpos(counts_row, 0)
          inner.addstr(counts_text.ljust(inner_w))
        end

        if session.filter_present?
          render_field_into(
            win: inner,
            field: session.field,
            row: input_row,
            width: inner_w,
            base_role: :popup_input,
            base_attr: input_attr,
            region_attr: pair_attr(:region, fallback: ::Curses::A_REVERSE),
            suggestion_attr: pair_attr(:input_suggestion, fallback: input_attr),
          )
          cursor_x = session.field.cursor_x.to_i.clamp(0, [inner_w - 1, 0].max)
          win.setpos(1 + input_row, 1 + cursor_x)
        end

        stage_window(win)
      rescue RuntimeError => e
        raise unless e.message.include?("closed window") ||
                     e.message.include?("already closed window")

        nil
      ensure
        inner&.close if inner&.respond_to?(:close)
      end

      def render_prompt_popup(session:)
        win = session.win
        return unless win

        width = win.maxx
        height = win.maxy

        win.erase

        frame_attr = pair_attr(:popup_frame, fallback: ::Curses::A_NORMAL)
        popup_attr = pair_attr(:popup, fallback: ::Curses::A_NORMAL)
        input_attr = pair_attr(:popup_input, fallback: ::Curses::A_REVERSE)

        win.attrset(frame_attr)
        draw_popup_frame(win, width: width, height: height)

        if session.title && !session.title.empty?
          win.setpos(0, 2)
          win.addstr(" #{Fatty::Ansi.strip(session.title)} ")
        end

        inner_h = height - 2
        inner_w = width - 2
        return if inner_h <= 0 || inner_w <= 0

        inner = win.derwin(inner_h, inner_w, 1, 1)
        inner.bkgdset(popup_attr) if inner.respond_to?(:bkgdset)
        inner.erase
        inner.attrset(popup_attr)

        input_row = inner_h - 1

        if session.message && !session.message.empty?
          message = Fatty::Ansi.strip(session.message.to_s).tr("\r\n", " ")
          message = Fatty::Ansi.truncate_visible(message, inner_w)

          inner.setpos(0, 0)
          inner.addstr(message.ljust(inner_w))
        end

        render_field_into(
          win: inner,
          field: session.field,
          row: input_row,
          width: inner_w,
          base_role: :popup_input,
          base_attr: input_attr,
          region_attr: pair_attr(:region, fallback: ::Curses::A_REVERSE),
          suggestion_attr: pair_attr(:input_suggestion, fallback: input_attr),
        )

        cursor_x = session.field.cursor_x.to_i.clamp(0, [inner_w - 1, 0].max)
        show_cursor
        win.setpos(1 + input_row, 1 + cursor_x)

        stage_window(inner)
        stage_window(win)
      ensure
        inner&.close if inner&.respond_to?(:close)
      end

      def restore_cursor(field)
        win = context.input_win
        return unless win

        cols = win.respond_to?(:maxx) ? win.maxx : @screen.input_rect.cols
        x = field.cursor_x.to_i.clamp(0, [cols - 1, 0].max)
        win.setpos(0, x)
        stage_window(win)
      end

      def begin_frame
      end

      def finish_frame
        ::Curses.doupdate
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

      def hide_cursor
        ::Curses.curs_set(0)
        self
      end

      def show_cursor
        ::Curses.curs_set(1)
        self
      end

      private

      # simplecov:disable

      def available_colors
        ::Curses.colors
      end

      def ansi_lines?(lines)
        lines.any? { |line| line.to_s.include?("\e[") }
      end

      def after_apply_theme!
        context.apply_palette(palette)
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

      def scroll_output_window_delta!(delta:, lines:, viewport:, highlights:)
        Fatty.debug("calling scroll_output_window_delta!", tag: :scrolling)
        win = context.output_win
        return unless win

        height = viewport.height
        base_attr = pair_attr(:output, fallback: ::Curses::A_NORMAL)
        win.attrset(base_attr)
        win.scrl(delta)
        if delta.positive?
          start_y = height - delta
          start_y = 0 if start_y < 0

          (start_y...height).each do |y|
            draw_output_row(
              win,
              line: lines[y],
              y: y,
              abs_line: viewport.top + y,
              highlights: highlights,
            )
          end
        else
          count = -delta
          count = height if count > height

          (0...count).each do |y|
            draw_output_row(
              win,
              line: lines[y],
              y: y,
              abs_line: viewport.top + y,
              highlights: highlights,
            )
          end
        end
        stage_window(win)
      end

      def draw_status_lines(status_session)
        win = context.status_win
        return unless win

        rect = screen.status_rect
        base_attr = pair_attr(status_session.role, fallback: ::Curses::A_REVERSE)
        lines = status_segment_lines(status_session)
        win.bkgdset(base_attr) if win.respond_to?(:bkgdset)
        win.erase
        rect.rows.times do |row|
          draw_status_row(
            win,
            row: row,
            cols: rect.cols,
            segments: lines[row] || [],
            base_attr: base_attr,
          )
        end
        stage_window(win)
      end

      def draw_status_row(win, row:, cols:, segments:, base_attr:)
        win.setpos(row, 0)
        remaining = cols

        segments.each do |segment|
          break if remaining <= 0

          text = segment[:text].to_s.tr("\r\n", " ")
          text = Fatty::Ansi.truncate_visible(text, remaining)
          next if text.empty?

          segment_role = segment[:role] || :status
          role_attr = pair_attr(segment_role, fallback: base_attr)

          attr =
            if segment[:style]
              ansi_style_attr(
                segment[:style],
                fallback: role_attr,
                fallback_role: segment_role,
              )
            else
              role_attr
            end

          win.attrset(attr)
          win.addstr(text)
          remaining -= Fatty::Ansi.visible_length(text)
        end

        if remaining.positive?
          win.attrset(base_attr)
          win.addstr(" " * remaining)
        end
      end

      def draw_output_lines(lines, viewport:, highlights: nil)
        context.reset_ansi_pairs!

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
        # plain = Fatty::Ansi.plain_text(line.to_s)
        # slices = build_line_slices(plain, ranges: curses_ranges) do |_style|
        #   base_attr
        # end
        slices = build_line_slices(line.to_s, ranges: curses_ranges) do |style|
          ansi_style_attr(style, fallback: base_attr)
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

      def render_field_into(win:, field:, row:, width:, base_attr:, region_attr:, suggestion_attr:, base_role: :input)
        safe_width = [width - 1, 0].max
        return if safe_width <= 0

        win.attrset(base_attr)
        win.setpos(row, 0)
        win.addstr(" " * safe_width)
        win.setpos(row, 0)

        remaining = safe_width
        field_segments(
          field,
          base_role: base_role,
          suggestion_role: :input_suggestion,
          region_role: :region,
        ).each do |segment|
          break if remaining <= 0

          attr =
            if segment[:style]
              ansi_style_attr(segment[:style], fallback: base_attr, fallback_role: base_role)
            else
              case segment[:role]
              when :region then region_attr
              when :input_suggestion then suggestion_attr
              else base_attr
              end
            end
          text = segment[:text].to_s.tr("\r\n", " ")
          text = Fatty::Ansi.truncate_visible(text, remaining)
          next if text.empty?

          win.attrset(attr)
          win.addstr(text)
          remaining -= Fatty::Ansi.visible_length(text)
        end
      end

      def ansi_style_attr(style, fallback:, fallback_role: :output)
        attr = fallback

        if style.fg || style.bg
          fg = curses_color_for_style(style.fg)
          bg = curses_color_for_style(style.bg)

          role_spec = palette[fallback_role] || palette[:output] || {}
          fg = role_spec[:fg] if fg.nil?
          bg = role_spec[:bg] if bg.nil?

          fallback_pair_id = Fatty::Colors::Pairs::ROLE_TO_PAIR.fetch(fallback_role)
          pair_id = context.ansi_pair_for(
            fg,
            bg,
            fallback_pair_id: fallback_pair_id,
          )

          attr = ::Curses.color_pair(pair_id)
        end

        attr |= ::Curses::A_BOLD if style.bold
        attr |= ::Curses::A_DIM if style.respond_to?(:dim) && style.dim
        attr |= ::Curses::A_UNDERLINE if style.underline
        attr |= ::Curses::A_REVERSE if style.reverse
        attr
      end

      def curses_color_for_style(color)
        case color
        when nil
          nil
        when Integer
          Fatty::Color.clamp_index(color, available_colors: available_colors)
        when Array
          Fatty::Color.resolve(
            Fatty::Color.xterm_index_for_rgb(color[0], color[1], color[2]),
            available_colors: available_colors,
          )
        end
      end
    end
  end
end
