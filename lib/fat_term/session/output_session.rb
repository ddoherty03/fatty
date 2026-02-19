# frozen_string_literal: true

module FatTerm
  class OutputSession < Session
    attr_reader :output, :viewport, :pager, :pager_field

    def initialize(keymap: nil, views: [])
      super(keymap: keymap, views: views)
      @output   = FatTerm::OutputBuffer.new(max_lines: 500_000)
      @viewport = FatTerm::Viewport.new(height: 10)
      mode = FatTerm::Config.config.dig(:output, :mode)&.to_sym || :paging
      @default_output_mode = mode
      @pager = FatTerm::Pager.new(output: @output, viewport: @viewport, mode: mode)
      # Pager minibuffer shown on the last row of the output pane when paging is
      # active.
      @pager_field = FatTerm::InputField.new(prompt: -> { pager_status_prompt })
    end

    def append_output(text)
      ntrim = @output.append(text.to_s)
      @pager.on_append(ntrim: ntrim)
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

    def reset_for_command!
      reset_output!
      mode = @default_output_mode #FatTerm::Config.config.dig(:output, :mode)&.to_sym || :paging
      @pager.reset!(mode: mode)
    end

    # True when the pager is currently holding the screen (i.e., paging mode is
    # active and the output is paused).
    def pager_active?
      @pager.reserve_prompt_row?
    end

    # When the pager is active, the last output row is reserved for the pager
    # InputField. This returns the viewport to use for rendering the output
    # content itself.
    def pager_viewport
      if pager_active? && @viewport.height > 1
        FatTerm::Viewport.new(top: @viewport.top, height: @viewport.height - 1)
      else
        @viewport
      end
    end

    def pager_status_prompt
      total = @output.lines.length
      bottom = [@viewport.top + @viewport.height, total].min

      pct =
        if total.positive?
          ((bottom * 100.0) / total).round
        end

      if pct
        "--More--  #{bottom}/#{total} (#{pct}%) "
      else
        "--More--  #{bottom} "
      end
    end

    def reset_pager!
      # Start the next command from the bottom of existing scrollback.
      @viewport.page_bottom(@output.lines)
      @pager.reset!(total_lines: @output.lines.length, mode: @default_output_mode)
    end
  end
end
