# frozen_string_literal: true

module FatTerm
  class OutputSession < Session
    attr_reader :output, :viewport

    def initialize(**kwargs)
      super(**kwargs)
      @output   = FatTerm::OutputBuffer.new
      @viewport = FatTerm::Viewport.new(height: 10)
    end

    # Append text to output, keep viewport consistent.
    # If follow is true, keep the viewport pinned to bottom *only if* it was
    # already at bottom (so paging doesn't get yanked).
    def append_output(text, follow: true)
      at_bottom = @viewport.at_bottom?(@output.lines.length)

      ntrim = @output.append(text.to_s)
      @viewport.adjust_for_trim(ntrim)
      @viewport.scroll_to_bottom(@output.lines) if follow && at_bottom

      ntrim
    end

    def reset_output!
      @output.lines.clear
      @viewport.reset
    end

    def resize_output!(terminal)
      @viewport.height = terminal.screen.output_rect.rows
      @viewport.clamp!(@output.lines)
    end
  end
end
