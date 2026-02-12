# frozen_string_literal: true

module FatTerm
  class OutputSession < Session
    attr_reader :output, :viewport

    def initialize(keymap: nil, views: [])
      super(keymap: keymap, views: views)
      @output   = FatTerm::OutputBuffer.new
      @viewport = FatTerm::Viewport.new(height: 10)
    end

    def append_output(text, follow: true)
      ntrim = @output.append(text.to_s)
      @viewport.adjust_for_trim(ntrim)
      out_lines = @output.lines
      if follow
        @viewport.page_bottom(out_lines)
      else
        @viewport.clamp!(out_lines)
      end
      ntrim
    end

    def reset_output!
      @output.lines.clear
      @viewport.reset
    end

    def resize_output!(terminal:)
      @viewport.height = terminal.screen.output_rect.rows
      @viewport.clamp!(@output.lines)
    end
  end
end
