# frozen_string_literal: true

module Fatty
  class Renderer
    class Truecolor < Fatty::Renderer
      include Fatty::Curses::WindowStyling

      def initialize(...)
        super
        @ansi_renderer = Fatty::Ansi::Renderer.new
        @pending_ansi_draws = []
        @cursor_visible = true
      end

      def render_status(status_session)
        state = status_state(status_session)
        return if state == @last_status_state

        @last_status_state = state

        draw_status_lines(status_session)
      end

      def render_alert(alert_session)
        state = alert_state(alert_session)
        return if state == @last_alert_state

        alert = alert_session.current
        @last_alert_state = state
        text = alert ? alert.format : ""
        role = alert ? alert_role(alert.role) : :alert_info

        queue_ansi_line(
          row: screen.alert_rect.row,
          col: screen.alert_rect.col,
          width: screen.alert_rect.cols,
          text: text,
          role: role,
        )
      end

      def render_output(output_session, viewport: output_session.viewport)
        lines = viewport.slice(output_session.visible_lines)
        normalized = normalized_highlights(output_session.highlights)
        line_number_width =
          if output_session.line_numbers?
            output_session.output.lines.length.to_s.length
          end

        curr = output_state(output_session, viewport: viewport)
        return if curr == @last_output_state

        draw_output_lines(
          lines,
          viewport: viewport,
          highlights: normalized,
          line_number_width: line_number_width,
        )
        @last_pager_field_state = nil
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

      def clear_input_field
        @last_input_state = nil
        queue_ansi_line(
          row: screen.input_rect.row,
          col: screen.input_rect.col,
          width: screen.input_rect.cols,
          text: "",
          role: :input,
        )
      end

      def render_pager_field(field, row:, role: :pager_status)
        state = pager_field_state(field, row: row, role: role)
        return if state == @last_pager_field_state

        @last_pager_field_state = state
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

        # Draw the displayed items inside the window with a gutter to have an
        # indicator of what is selected, if any.
        filter_present = session.filter_present?
        counts_present = session.counts_present?
        input_row = filter_present ? inner_h - 1 : nil
        counts_row =
          if counts_present
            filter_present ? input_row - 1 : inner_h - 1
          end

        list_end =
          if counts_present
            counts_row
          elsif filter_present
            input_row
          else
            inner_h
          end
        list_h = [list_end - row, 0].max

        layout = PopupLayout.new(row: row, width: inner_w, height: list_h)
        render_popup_items(session: session, layout: layout)

        # Draw the "counts" line to indicate the total number of items, items
        # selected, and items displayed.
        layout = PopupLayout.new(row: counts_row, width: inner_w)
        render_popup_counts(session: session, layout: layout) if session.counts_present?

        if filter_present
          # Draw the input field for the user to type narrowing selection
          # queries.
          layout = PopupLayout.new(row: input_row, width: inner_w)
          render_popup_input_field(session: session, layout: layout)
        end
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
        show_cursor
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

      def clear_physical_screen!
        $stdout.write("\e[2J\e[H")
        $stdout.flush
        invalidate!
        self
      end

      def restore_cursor(field)
        return self unless @cursor_visible

        rect = screen.input_rect
        x = field.cursor_x.to_i.clamp(0, [rect.cols - 1, 0].max)
        queue_ansi_cursor(row: rect.row, col: rect.col + x)
      end

      def show_cursor
        @cursor_visible = true
        ::Curses.curs_set(1)
        @ansi_renderer.write_ansi(@ansi_renderer.hide_cursor)
        self
      end

      def hide_cursor
        @cursor_visible = false
        ::Curses.curs_set(0)
        @ansi_renderer.write_ansi(@ansi_renderer.hide_cursor)
        self
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

      # Restore cursor into the output window at a specific *output-win* row.
      # `row:` is 0..(screen.output_rect.rows-1), NOT an absolute screen row.
      def restore_output_cursor(field, row:)
        return self unless @cursor_visible

        cols = @screen.cols
        x = field.cursor_x.to_i
        x = x.clamp(0, [cols - 1, 0].max)
        row0 = @screen.output_rect.row
        col0 = @screen.output_rect.col
        cols = @screen.output_rect.cols
        @pending_ansi_draws << {
          type: :cursor,
          row: row0 + row,
          col: col0 + x.clamp(0, [cols - 1, 0].max),
        }
      end

      private

      # simplecov:disable

      def sync_window_background(win, role)
        return unless win

        attr = pair_attr(role, fallback: ::Curses::A_NORMAL)
        win.bkgdset(attr) if win.respond_to?(:bkgdset)
        win.erase
        win.noutrefresh if win.respond_to?(:noutrefresh)
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
        selected = session.current
        start = session.scroll_start(list_h: layout.height)

        (0...layout.height).each do |offset|
          item_index = start + offset
          item_selected = item_index == selected
          role = item_selected ? :popup_selection : :popup

          line = popup_item_text(
            session,
            items: items,
            item_index: item_index,
            selected: item_selected,
            width: layout.width,
          )

          queue_ansi_popup_fill_row(
            win: win,
            inner_row: layout.row + offset,
            width: layout.width,
            role: role,
          )

          queue_ansi_popup_line(
            win: win,
            inner_row: layout.row + offset,
            width: layout.width,
            text: line,
            role: role,
          )
        end
      end

      def popup_item_text(session, items:, item_index:, selected:, width:)
        line = ""

        if item_index < items.length
          item = items[item_index]
          gutter = session.gutter_for(item: item, selected: selected)
          text = Fatty::Ansi.strip(item.to_s).tr("\r\n", " ")
          available = [width - Fatty::Ansi.visible_length(gutter), 0].max
          text = Fatty::Ansi.truncate_visible(text, available)
          line = Fatty::Ansi.truncate_visible(gutter + text, width)
        end

        line
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

        queue_ansi_popup_fill_row(
          win: win,
          inner_row: layout.row,
          width: layout.width,
          role: :popup_input,
        )

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

      def draw_output_lines(lines, viewport:, highlights: nil, line_number_width: nil)
        rect = screen.output_rect

        rect.rows.times do |y|
          visible_line = lines[y]
          text = visible_line&.text.to_s
          abs_line = visible_line ? visible_line.number - 1 : nil
          ranges = highlight_ranges_for_line(highlights, abs_line)
          segments = []

          if visible_line && line_number_width
            number_text = visible_line.number.to_s.rjust(line_number_width, "0")
            segments << {
              text: "#{number_text}: ",
              role: :line_number,
            }
          end

          segments.concat(output_segments(text, ranges: ranges))
          queue_ansi_segments_line(
            row: rect.row + y,
            col: rect.col,
            width: rect.cols,
            segments: segments,
            fill_role: :output,
          )
        end
      end

      def draw_status_lines(status_session)
        rect = screen.status_rect
        lines = status_segment_lines(status_session)

        rect.rows.times do |y|
          queue_ansi_segments_line(
            row: rect.row + y,
            col: rect.col,
            width: rect.cols,
            segments: lines[y] || [],
            fill_role: status_session.role,
          )
        end
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

      def queue_ansi_popup_fill_row(win:, inner_row:, inner_col: 0, width:, role:)
        queue_ansi_popup_line(
          win: win,
          inner_row: inner_row,
          inner_col: inner_col,
          width: width,
          text: " " * width,
          role: role,
        )
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
            if @cursor_visible
              @ansi_renderer.write_ansi("\e[#{draw[:row] + 1};#{draw[:col] + 1}H")
            end
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
        @ansi_renderer.write_ansi(@cursor_visible ? "\e[?25h" : "\e[?25l")
      end
    end
  end
end
