# frozen_string_literal: true

module FatTerm
  class Pager
    include FatTerm::Actionable

    action_on :pager
    attr_reader :mode

    def initialize(output:, viewport:, mode: :paging)
      @output   = output
      @viewport = viewport
      # @mode can be :paging, or :scrolling
      # - paging: the viewport displays one page worth of output at a time,
      # - scrolling: the viewport displays output continuously as it is produced.
      @mode   = mode
      @paused = false
      @autoscroll = false
      @last_nav_dir = nil
      # Search state (used by SearchSession, but owned here so paging repeats and
      # highlighting survive after the SearchSession closes).
      @search = {
        pattern: nil,
        regex: false,
        re: nil,
        original_direction: nil,
        last_direction: nil,
        last: nil, # { line: Integer, from: Integer, to: Integer }
        last_view_top: nil,
        pending_wrap: nil, # :forward/:backward
      }
    end

    def paused?
      @mode == :paging && @paused
    end

    def reserve_prompt_row?
      paused?
    end

    def autoscroll?
      @autoscroll
    end

    # The pager sometimes reserves a row for a status/minibuffer line. When it
    # does, paging calculations must use a reduced page height so that the
    # pause threshold and page-step size match what is actually rendered.
    def page_height
      h = @viewport.height
      h -= 1 if reserve_prompt_row?
      [h, 1].max
    end

    # Called by OutputSession after new text is appended.
    def on_append(ntrim:)
      @viewport.adjust_for_trim(ntrim)
      lines = @output.lines
      total = lines.size

      case @mode
      when :scrolling
        # In scrolling mode, the viewport is allowed to move continuously.
        # Autoscroll animation (after switching from paging -> scrolling) is
        # driven by #autoscroll_step? in ShellSession#tick, not by incremental
        # scroll deltas during append.
        @viewport.clamp!(lines)
      when :paging
        if @anchor
          produced = total - @anchor

          if produced <= 0
            return
          end

          # While producing the first page, keep the viewport pinned to the anchor.
          @viewport.top = @anchor
          @viewport.clamp!(lines)
          if produced >= page_height
            @paused = true
          end
          return
        end
        if @paused
          @viewport.clamp!(lines)
          return
        end

        # No anchor and not yet paused: once the output exceeds a single page,
        # pause and show the first page.
        if total > page_height
          @paused = true
          @viewport.page_top
        end
        # Otherwise user is not at bottom; don't force movement.
        @viewport.clamp!(lines)
      end
    end

    def act_on(action, *args, env:, **kwargs)
      raise FatTerm::ActionError, "Unknown action: #{action}" unless action

      if FatTerm::Actions.registered?(action)
        FatTerm::Actions.call(action, env, *args, **kwargs)
      elsif respond_to?(action)
        public_send(action, *args, **kwargs)
      else
        raise FatTerm::ActionError, "Unknown action: #{action}"
      end
    end

    desc "Page up in output"
    action :page_up do |count: 1|
      @mode = :paging
      @paused = true
      @last_nav_dir = :up
      step = page_height
      count.to_i.times { @viewport.scroll_up(@output.lines, step) }
      @viewport.clamp!(@output.lines)
    end

    desc "Page down in output"
    action :page_down do |count: 1|
      @mode = :paging
      @paused = true
      @last_nav_dir = :down
      step = page_height
      count.to_i.times { @viewport.scroll_down(@output.lines, step) }
      @viewport.clamp!(@output.lines)
    end

    desc "Jump to end and follow output"
    action :end_of_output do
      @mode = :scrolling
      @paused = false
      @last_nav_dir = :down
      @anchor = nil
      @viewport.page_bottom(@output.lines)
    end

    desc "Scroll up"
    action :scroll_up do |count: 1|
      @mode = :paging
      @paused = true
      @last_nav_dir = :up
      count.to_i.times { @viewport.scroll_up(@output.lines) }
      @viewport.clamp!(@output.lines)
    end

    desc "Scroll down"
    action :scroll_down do |count: 1|
      @mode = :paging
      @paused = true
      @last_nav_dir = :down
      count.to_i.times { @viewport.scroll_down(@output.lines) }
      @viewport.clamp!(@output.lines)
    end

    desc "Page top"
    action :page_top do
      @mode = :paging
      @paused = true
      @last_nav_dir = :up
      @viewport.page_top
      @viewport.clamp!(@output.lines)
    end

    desc "Page bottom"
    action :page_bottom do
      @mode = :paging
      @paused = true
      @last_nav_dir = :down
      @viewport.page_bottom(@output.lines)
    end

    desc "Switch from paging to scrolling"
    action :paging_to_scrolling do
      @mode = :scrolling
      @paused = false
      @anchor = nil
      @last_nav_dir = :down
      @autoscroll = true
      @viewport.clamp!(@output.lines)
      # Make it visibly start immediately, even if no further appends happen.
      autoscroll_step?(max_lines: @viewport.height)
    end

    desc "Toggle between paging and scrolling"
    action :toggle_paging do
      @last_nav_dir = :down
      if @mode == :paging
        @mode = :scrolling
        @paused = false
        @autoscroll = true   # keep if you like the animated “catch up”
      else
        @mode = :paging
        @paused = true
        @autoscroll = false
        @anchor = nil        # ensure no command-anchored paging behavior kicks in
        @viewport.clamp!(@output.lines)
      end
    end

    desc "Exit paging and return control to normal input."
    action :quit_paging do
      @paused = false
      @mode = :scrolling if @mode == :paging
      @anchor = nil
    end

    def at_top?
      @viewport.at_top?
    end

    def at_bottom?
      @viewport.at_bottom?(@output.lines.size)
    end

    def nav_arrow
      if at_top?
        "⇓"
      elsif at_bottom?
        "⇑"
      elsif @last_nav_dir == :up
        "⇑"
      elsif @last_nav_dir == :down
        "⇓"
      else
        ""
      end
    end

    def begin_command!(anchor:)
      @mode = :paging
      @paused = false
      @anchor = anchor
      @autoscroll = false
    end

    def reset!(total_lines: 0, mode: :paging)
      @mode = mode
      @paused = false
      @autoscroll = false
      @anchor = nil
    end

    def autoscroll_step?(max_lines: 200)
      lines = @output.lines
      total = lines.length
      return false if total <= 0

      # If already at bottom, stop autoscroll.
      if @viewport.at_bottom?(total)
        @autoscroll = false
        return false
      end

      # Move down, but cap the work per tick so input stays responsive.
      remaining = @viewport.max_top(total) - @viewport.top
      n = [remaining, max_lines].min
      @viewport.scroll_down(lines, n)

      if @viewport.at_bottom?(total)
        @autoscroll = false
      end
      true
    end

    # --- Search -----------------------------------------------------------

    def search_active?
      !@search[:re].nil?
    end

    # Sets the search pattern and moves the viewport to the next match.
    # Returns a result hash:
    #   { status: :moved }
    #   { status: :not_found }
    #
    # The initial search includes the currently visible page:
    # - forward starts at viewport.top
    # - backward starts at viewport.bottom_index(total)
    def search_set!(pattern:, regex:, direction:)
      pattern = pattern.to_s
      if pattern.strip.empty?
        clear_search!
        return { status: :not_found }
      end

      re = compile_search_regexp(pattern, regex: regex)
      @search[:pattern] = pattern
      @search[:regex] = !!regex
      @search[:re] = re
      @search[:last_direction] = direction.to_sym
      @search[:original_direction] = direction.to_sym
      @search[:last] = nil
      @search[:pending_wrap] = nil

      search_step!(direction: direction, initial: true)
    rescue RegexpError => e
      clear_search!
      { status: :not_found, message: "Invalid regexp: #{e.message}" }
    end

    def clear_search!
      @search[:pattern] = nil
      @search[:regex] = false
      @search[:re] = nil
      @search[:last] = nil
      @search[:original_direction] = nil
      @search[:pending_wrap] = nil
    end

    # Steps to the next match in +direction+.
    # If no match exists without wrapping, returns :boundary and requires a
    # second step in the same direction to wrap.
    # NOTE:
    # Regex search is strictly line-local.
    # Matches never span line boundaries even if '.' would
    # normally match '\n'. This preserves pager navigation,
    # viewport anchoring, and renderer simplicity.
    def search_step!(direction:, initial: false, update_origin: true)
      direction = direction.to_sym
      re = @search[:re]
      @search[:last_direction] = direction.to_sym
      if update_origin
        @search[:original_direction] = direction.to_sym
      end
      return { status: :not_found } unless re

      lines = @output.lines
      total = lines.length
      return { status: :not_found } if total.zero?

      start = search_start_position(direction: direction, total: total, initial: initial)
      found = find_next_match(lines, re, start, direction: direction, wrap: false)

      if found
        apply_search_match(found)
        @search[:pending_wrap] = nil
        return { status: :moved }
      end

      if @search[:pending_wrap] == direction
        # Second invocation in the same direction: wrap.
        wrap_start = wrap_start_position(direction: direction, total: total)
        found = find_next_match(lines, re, wrap_start, direction: direction, wrap: true)
        @search[:pending_wrap] = nil

        if found
          apply_search_match(found)
          return { status: :moved, wrapped: true }
        end

        return { status: :not_found }
      end

      @search[:pending_wrap] = direction
      { status: :boundary, message: boundary_message(direction: direction) }
    end

    # Vim/less semantics:
    # - n repeats in the original direction (set by / ? C-s C-r)
    # - N repeats in the opposite direction
    def search_repeat_next!
      dir = (@search[:original_direction] || :forward).to_sym
      search_step!(direction: dir, update_origin: false)
    end

    def search_repeat_prev!
      origin = (@search[:original_direction] || :forward).to_sym
      dir = (origin == :forward ? :backward : :forward)
      search_step!(direction: dir, update_origin: false)
    end

    # Exposes the last match for render-layer highlighting.
    # (We only highlight the last match for now; later we can highlight all
    # visible matches.)
    def search_last_match
      @search[:last]
    end

    # Returns highlight ranges for all matches within the given viewport.
    #
    # Format:
    #   {
    #     abs_line_index => [[from, to, :secondary], [from, to, :secondary], ...,
    #                       [from, to, :primary]],
    #     ...
    #   }
    #
    # Ranges are in *visible text* coordinates (ANSI already stripped), matching
    # the renderer’s slice planner / highlighting behavior.
    def search_visible_highlights(viewport:)
      re = @search[:re]
      return nil unless re

      lines = @output.lines
      total = lines.length
      return nil if total.zero?

      top = viewport.top.to_i
      bottom = viewport.bottom_index(total)
      current = @search[:last]
      out = {}
      (top..bottom).each do |i|
        text = visible_text(lines[i])
        next if text.nil? || text.empty?

        ranges = []
        text.to_enum(:scan, re).each do
          m = Regexp.last_match
          ranges << [m.begin(0), m.end(0), :secondary]
        end
        next if ranges.empty?

        # Promote the current match to :primary, removing the duplicate secondary
        # range if present.
        if current && current[:line].to_i == i
          cf = current[:from].to_i
          ct = current[:to].to_i
          ranges.reject! { |a, b, _role| a == cf && b == ct }
          ranges << [cf, ct, :primary]
        end
        ranges.sort_by!(&:first)
        out[i] = ranges
      end
      out.empty? ? nil : out
    end

    def search_label
      return unless @search[:re]

      # Keep showing the direction of the most recent movement (nice UX),
      # while repeat semantics depend on original_direction.
      arrow = (@search[:last_direction] == :backward ? "↑" : "↓")
      prefix = @search[:regex] ? "re:" : ""
      pat = @search[:pattern].to_s
      "#{arrow} #{prefix}#{pat}"
    end

    private

    # Return the visible text for a line, with ANSI escapes removed.
    # Search offsets are computed in this coordinate space so rendering
    # highlights align with what the user sees.
    def visible_text(str)
      FatTerm::Ansi.segment(str.to_s).map(&:first).join
    end

    def compile_search_regexp(pattern, regex:)
      if regex
        Regexp.new(pattern)
      else
        Regexp.new(Regexp.escape(pattern))
      end
    end

    def search_start_position(direction:, total:, initial:)
      last = @search[:last]
      # If the user has navigated since the last match (e.g. G/g/PageUp),
      # repeat search should start from the current viewport edge, not from
      # the prior match location.
      viewport_unchanged = (last && @search[:last_view_top] == @viewport.top)

      if last && viewport_unchanged
        if direction == :forward
          { line: last[:line], col: last[:to] }
        else
          { line: last[:line], col: last[:from] }
        end
      elsif direction == :forward
        { line: @viewport.top, col: 0 }
      else
        # Use a very large col so scan_backward includes matches on the
        # starting line (our backward scan treats start_col as an upper bound).
        li = @viewport.bottom_index(total)
        { line: li, col: search_start_col_for(li) }
      end
    end

    def search_start_col_for(line_index)
      line = @output.lines[line_index]
      # Use end-of-line as the backward scan upper bound so the starting line
      # is included. +1 avoids edge weirdness when match ends exactly at len.
      if line
        visible_text(line).chomp.length + 1
      else
        1_000_000_000
      end
    end

    def wrap_start_position(direction:, total:)
      if direction == :forward
        { line: 0, col: 0 }
      else
        li = total - 1
        { line: li, col: search_start_col_for(li) }
      end
    end

    def boundary_message(direction:)
      if direction == :forward
        "Bottom reached — hit C-s (or n) again to wrap to top"
      else
        "Top reached — hit C-r (or N) again to wrap to bottom"
      end
    end

    def find_next_match(lines, re, start, direction:, wrap:)
      line_i = start[:line].to_i
      col = start[:col].to_i

      if direction == :forward
        scan_forward(lines, re, line_i, col)
      else
        scan_backward(lines, re, line_i, col)
      end
    end

    def scan_forward(lines, re, start_line, start_col)
      i = start_line.clamp(0, lines.length - 1)
      while i < lines.length
        text = visible_text(lines[i])
        from = (i == start_line ? start_col : 0)
        m = re.match(text, from)
        return { line: i, from: m.begin(0), to: m.end(0) } if m

        i += 1
      end
      nil
    end

    def scan_backward(lines, re, start_line, start_col)
      i = start_line.clamp(0, lines.length - 1)
      while i >= 0
        text = visible_text(lines[i])
        # For now, we search the whole line and select the last match.
        # If we're repeating within the same line, restrict to before start_col.
        limit = (i == start_line ? start_col : nil)
        last = nil
        text.to_enum(:scan, re).each do
          m = Regexp.last_match
          break if limit && m.end(0) > limit

          last = m
        end
        return { line: i, from: last.begin(0), to: last.end(0) } if last

        i -= 1
      end
      nil
    end

    def apply_search_match(match)
      @search[:last] = match
      line = match[:line]
      # Make sure we're in paging mode when navigating search results.
      @mode = :paging
      @paused = true
      @last_nav_dir = :down

      # Position the match line near the middle when possible.
      half = (@viewport.height / 2)
      @viewport.top = [line - half, 0].max
      @search[:last_view_top] = @viewport.top
    end
  end
end
