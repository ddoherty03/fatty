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
        # driven by #autoscroll_step in ShellSession#tick, not by incremental
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
      FatTerm.debug("paging_to_scrolling: mode=#{@mode} paused=#{@paused} top=#{@viewport.top} total=#{@output.lines.length}")
      @mode = :scrolling
      @paused = false
      @anchor = nil
      @last_nav_dir = :down
      @autoscroll = true
      @viewport.clamp!(@output.lines)
      # Make it visibly start immediately, even if no further appends happen.
      autoscroll_step(max_lines: @viewport.height)
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

    def autoscroll_step(max_lines: 200)
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
  end
end
