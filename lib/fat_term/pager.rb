module FatTerm
  class Pager
    include FatTerm::Actionable

    attr_reader :mode

    def initialize(output:, viewport:)
      @output   = output
      @viewport = viewport
      # @mode can be :follow, :paging, or :scrolling
      # - follow: the viewport hugs the last page of output,
      # - paging: the viewport displays one page worth of output at a time,
      #   set @pager_active = true,
      # - scrolling: the viewport displays output continuously as it is produced.
      @mode   = :follow
      @paused = false
    end

    def paused?
      @mode == :paging && @paused
    end

    def reserve_prompt_row?
      paused?
    end

    # Called by OutputSession after new text is appended.
    def on_append(ntrim:)
      @viewport.adjust_for_trim(ntrim)
      lines = @output.lines

      case @mode
      when :follow
        @viewport.page_bottom(lines)
      when :scrolling
        @viewport.clamp!(lines)
      when :paging
        if @paused
          @viewport.clamp!(lines)
        else
          maybe_pause_at_page_end(lines)
        end
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
      count.to_i.times { @viewport.page_up(@output.lines) }
      @viewport.clamp!(@output.lines)
    end

    desc "Page down in output"
    action :page_down do |count: 1|
      @mode = :paging
      @paused = false
      count.to_i.times { @viewport.page_down(@output.lines) }
      pause_if_needed
    end

    desc "Jump to end and follow output"
    action :end_of_output do
      @mode = :follow
      @paused = false
      @viewport.page_bottom(@output.lines)
    end

    desc "Scroll up"
    action :scroll_up do |count: 1|
      @mode = :scrolling
      @paused = false
      count.to_i.times { @viewport.scroll_up(@output.lines) }
      @viewport.clamp!(@output.lines)
    end

    desc "Scroll down"
    action :scroll_down do |count: 1|
      @mode = :scrolling
      @paused = false
      count.to_i.times { @viewport.scroll_down(@output.lines) }
      @viewport.clamp!(@output.lines)
    end

    desc "Page top"
    action :page_top do
      @mode = :scrolling
      @paused = false
      @viewport.page_top
      @viewport.clamp!(@output.lines)
    end

    desc "Page bottom"
    action :page_bottom do
      @mode = :scrolling
      @paused = false
      @viewport.page_bottom(@output.lines)
    end

    desc "Switch from paging to scrolling"
    action :paging_to_scrolling do
      @mode = :scrolling
      @paused = false
      @viewport.clamp!(@output.lines)
    end

    private

    def maybe_pause_at_page_end(lines)
      @viewport.clamp!(lines)
      # simplest first cut: if append made us not-at-bottom, pause
      if lines.length > @viewport.height && !@viewport.at_bottom?(lines.length)
        @mode = :paging
        @paused = true
      else
        @viewport.page_bottom(lines)
      end
    end

    def pause_if_needed
      lines = @output.lines
      @viewport.clamp!(lines)
      if @mode == :paging && lines.length > @viewport.height && !@viewport.at_bottom?(lines.length)
        @paused = true
      end
    end
  end
end
