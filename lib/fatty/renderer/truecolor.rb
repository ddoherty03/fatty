# frozen_string_literal: true

module Fatty
  class Renderer
    class Truecolor < Fatty::Renderer
      include Fatty::Curses::WindowStyling

      def initialize(...)
        super
        @legacy = Fatty::Curses::Renderer.new(
          screen: @screen,
          context: @context,
        )
        @ansi_renderer = Fatty::Ansi::Renderer.new
        @pending_ansi_draws = []
      end

      # def method_missing(name, ...)
      #   if @legacy.respond_to?(name)
      #     @legacy.public_send(name, ...)
      #   else
      #     super
      #   end
      # end

      # def respond_to_missing?(name, include_private = false)
      #   @legacy.respond_to?(name, include_private) || super
      # end

      def render_status(text, role: :info)
        state = status_state(text, role)
        return if state == @last_status_state

        @last_status_state = state
        queue_ansi_line(
          row: screen.status_rect.row,
          col: screen.status_rect.col,
          width: screen.status_rect.cols,
          text: text,
          role: role,
        )
      end

      def render_alert(alert)
        state = alert_state(alert)
        return if state == @last_alert_state

        @last_alert_state = state
        text = alert ? alert.format : ""
        role = alert ? alert.role : :alert_info

        queue_ansi_line(
          row: screen.alert_rect.row,
          col: screen.alert_rect.col,
          width: screen.alert_rect.cols,
          text: text,
          role: role,
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

      def render_pager_field(field, row:, role: :pager_status)
        win = context.output_win
        return unless win

        row0, col0 = win.origin
        return unless row0 && col0

        cols = win.respond_to?(:maxx) ? win.maxx : @screen.cols

        queue_ansi_segments_line(
          row: row0 + row,
          col: col0,
          width: cols,
          segments: field_segments(
            field,
            base_role: role,
            suggestion_role: :input_suggestion,
            region_role: :region,
          ),
          fill_role: role,
        )
      end

      def render_popup(session:)
        state = popup_state(session)
        return if state == @last_popup_state

        @last_popup_state = state

        win = session.win
        return unless win

        row0, col0 = win.origin
        return unless row0 && col0

        width = win.maxx
        height = win.maxy
        inner_w = [width - 2, 0].max
        inner_h = [height - 2, 0].max

        # Draw the window with the border
        render_popup_frame(session: session)

        # Add any title
        render_popup_title(session: session) if session.title

        # Draw the message if any inside the window
        layout = PopupLayout.new(row: 0, width: inner_w)
        row = render_popup_message(session: session, layout: layout)

        counts_present = !!session.counts
        input_row = inner_h - 1
        counts_row = counts_present ? input_row - 1 : nil

        # Draw the displayed items inside the window with a gutter to have an
        # indicator of what is selected, if any.
        list_h = [inner_h - row - 1 - (counts_present ? 1 : 0), 0].max
        layout = PopupLayout.new(row: row, width: inner_w, height: list_h)
        render_popup_items(session: session, layout: layout)

        # Draw the "counts" line to indicate the total number of items, items
        # selected, and items displayed.
        layout = PopupLayout.new(row: counts_row, width: inner_w)
        render_popup_counts(session: session, layout: layout) if counts_present

        # Draw the input field for the user to type narrowing selection
        # queries.
        layout = PopupLayout.new(row: input_row, width: inner_w)
        render_popup_input_field(session: session, layout: layout)
      end

      def render_prompt_popup(session:)
        win = session.win
        return unless win

        row0, col0 = win.origin
        return unless row0 && col0

        inner_w = [win.maxx - 2, 0].max
        inner_h = [win.maxy - 2, 0].max
        return if inner_w <= 0 || inner_h <= 0

        render_popup_frame(session: session)
        render_popup_title(session: session) if session.title

        layout = PopupLayout.new(row: 0, width: inner_w)
        row = render_popup_message(session: session, layout: layout)

        layout = PopupLayout.new(row: row, width: inner_w)
        render_popup_input_field(session: session, layout: layout)
      rescue RuntimeError => e
        raise unless e.message.include?("closed window") ||
                     e.message.include?("already closed window")

        nil
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

      # In truecolor mode, curses windows must still have themed backgrounds.
      # ncurses may repaint or expose its backing store during getch/doupdate,
      # so we must keep the backing store visually consistent with ANSI output.
      def sync_backgrounds!
        return self unless context.truecolor

        sync_window_background(context.output_win, :output)
        sync_window_background(context.input_win, :input)
        sync_window_background(context.alert_win, :info)

        if @screen.status_rect.rows.positive?
          sync_window_background(context.status_win, :status)
        end
        self
      end

      private

      def sync_window_background(win, role)
        return unless win

        attr = pair_attr(role, fallback: ::Curses::A_NORMAL)
        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.noutrefresh if win.respond_to?(:noutrefresh)
      end

      def popup_state(session)
        [
          popup_border,
          session.message.to_s,
          session.displayed.map(&:to_s),
          session.selected,
          session.field.prompt_text.to_s,
          session.field.buffer.text.to_s,
          session.field.cursor_x,
          session.selected_labels.sort,
          session.counts,
          screen.rows,
          screen.cols,
        ]
      end

      def render_popup_title(session:)
        win = session.win
        return unless win
        return unless session.title

        row, col = win.origin
        return unless row && col

        width = [win.maxx - 4, 0].max
        text = " #{session.title} "[0, width]
        return if text.empty?

        queue_ansi_line(
          row: row,
          col: col + 2,
          width: text.length,
          text: text,
          role: :popup_frame,
        )
      end

      def render_popup_frame(session:)
        win = session.win
        return unless win

        width = win.maxx
        height = win.maxy
        return if width < 2 || height < 2

        row, col = win.origin
        return unless row && col

        b = popup_border
        # Draw the top frame
        queue_ansi_line(
          row: row,
          col: col,
          width: width,
          text: b[:tl] + (b[:h] * (width - 2)) + b[:tr],
          role: :popup_frame,
        )
        (1...(height - 1)).each do |y|
          # Draw the left frame
          queue_ansi_line(
            row: row + y,
            col: col,
            width: 1,
            text: b[:v],
            role: :popup_frame,
          )
          # Draw the right frame
          queue_ansi_line(
            row: row + y,
            col: col + width - 1,
            width: 1,
            text: b[:v],
            role: :popup_frame,
          )
        end
        # Draw the bottom frame
        queue_ansi_line(
          row: row + height - 1,
          col: col,
          width: width,
          text: b[:bl] + (b[:h] * (width - 2)) + b[:br],
          role: :popup_frame,
        )
      end

      def render_popup_message(session:, layout:)
        win = session.win
        return layout.row unless win

        return layout.row unless session.message && !session.message.empty?

        row = win.origin[0] + 1 + layout.row
        col = win.origin[1] + 1
        queue_ansi_line(
          row: row,
          col: col,
          width: layout.width,
          text: session.message.to_s,
          role: :popup,
        )
        layout.row + 1
      end

      def render_popup_items(session:, layout:)
        win = session.win
        return unless win

        items = session.displayed
        sel = session.selected
        start = session.scroll_start(list_h: layout.height)
        row = layout.row

        (0...layout.height).each do |i|
          idx = start + i
          selected = idx == sel
          role = selected ? :popup_selection : :popup
          line = ""
          if idx < items.length
            item = items[idx]
            gutter = session.gutter_for(item: item, selected: selected)
            avail = [layout.width - gutter.length, 0].max
            line = (gutter + item.to_s[0, avail])[0, layout.width]
          end
          queue_ansi_popup_line(
            win: win,
            inner_row: row + i,
            width: layout.width,
            text: line,
            role: role,
          )
        end
      end

      def render_popup_counts(session:, layout:)
        win = session.win
        return unless win

        row = win.origin[0] + 1 + layout.row
        col = win.origin[1] + 1
        queue_ansi_line(
          row: row,
          col: col,
          width: layout.width,
          text: popup_counts_text(session),
          role: :popup_counts,
        )
      end

      def render_popup_input_field(session:, layout:)
        win = session.win
        return unless win

        row = win.origin[0] + 1 + layout.row
        col = win.origin[1] + 1
        queue_ansi_segments_line(
          row: row,
          col: col,
          width: layout.width,
          segments: field_segments(
            session.field,
            base_role: :popup_input,
            suggestion_role: :input_suggestion,
            region_role: :region,
          ),
          fill_role: :popup_input,
        )
        cursor_x = session.field.cursor_x.to_i.clamp(0, [layout.width - 1, 0].max)
        queue_ansi_cursor(row: row, col: col + cursor_x)
      end

      def queue_ansi_popup_title(win:, title:)
        return unless title

        row, col = win.origin
        return unless row && col

        width = win.maxx
        text = " #{title} "[0, [width - 4, 0].max]
        return if text.empty?

        queue_ansi_line(
          row: row,
          col: col + 2,
          width: text.length,
          text: text,
          role: :popup_frame,
        )
      end

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

    def queue_ansi_popup_line(win:, inner_row:, inner_col: 0, width:, text:, role:)
      row, col = win.origin
      return unless row && col

      queue_ansi_line(
        row: row + 1 + inner_row,
        col: col + 1 + inner_col,
        width: width,
        text: text.to_s,
        role: role,
      )
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

    def queue_ansi_line(row:, col:, width:, text:, role: nil)
      spec = palette[role] || {}
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

      # Hide the cursor
      @ansi_renderer.write_ansi("\e[?25l")

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
      @pending_ansi_draws.clear
    ensure
      # Unhide the cursor
      @ansi_renderer.write_ansi("\e[?25h")
    end
  end
end
