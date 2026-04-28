# frozen_string_literal: true

require "tmpdir"

module Fatty
  class KeyTestSession < Session
    def id = :keytest

    def initialize(owner: nil)
      super(keymap: nil, views: [])
      @owner = owner
    end

    def init(terminal:)
      super
      @suggestions = []
      @owner ||= terminal.focused_session
      show_quit_status
      force_scrolling_output!
      append <<~TEXT
        Key test mode

        Press keys to inspect Fatty's decoding and binding resolution.
        Press q, ESC, or C-g to leave key test mode.

      TEXT
      []
    end

    def update_key(ev)
      if quit_key?(ev)
        append "Leaving key test mode.\n\n"
        return [[:terminal, :pop_modal]]
      end

      # append "  TERM:      #{terminal_name}\n"
      append ev.report
      snippet = ev.suggested_snippet(terminal_name)
      append anippet + "\n"
      @suggestions << snippet unless snippet.empty?
      show_quit_status
      []
    end

    def view(screen:, renderer:)
      # Intentionally blank. The underlying shell session renders the output
      # pane; this modal only captures keys and appends diagnostic text.
      nil
    end

    def close
      write_suggestions!
      restore_owner_pager!
      terminal.clear_status if terminal.respond_to?(:clear_status)
      nil
    end

    private

    def append(text)
      return unless @owner && @owner.respond_to?(:append_output)

      force_scrolling_output!

      before = @owner.output.lines.length
      @owner.append_output(text.to_s, follow: false)

      height = @owner.viewport.height.to_i
      added = @owner.output.lines.length - before

      if added >= height
        @owner.viewport.top = before
        @owner.viewport.clamp!(@owner.output.lines)
      else
        @owner.viewport.page_bottom(@owner.output.lines)
      end

      terminal.renderer.reset_frame_cache if terminal.respond_to?(:renderer)
    end

    def force_scrolling_output!
      if @owner && @owner.respond_to?(:pager)
        @owner.pager.paging_to_scrolling
      end
    end

    def quit_key?(ev)
      ev.key == :q ||
        ev.key == :escape ||
        (ev.key == :g && ev.ctrl?)
    end

    def show_quit_status
      terminal.warn("KeyTest — press q, ESC, or C-g to quit  (TERM: #{terminal_name})")
    end

    def write_suggestions!
      suggestions = @suggestions.uniq
      return if suggestions.empty?

      path = File.join(
        Dir.tmpdir,
        "fatty-keytest-#{Time.now.strftime('%Y%m%d-%H%M%S')}.yml"
      )

      File.write(path, suggestions.join("\n\n"))

      append <<~TEXT
        =======================================================
        KeyTest suggestions written to:
        #{path}

      TEXT

      terminal.good("KeyTest suggestions written to #{path}")
    end

    def restore_owner_pager!
      if @owner && @owner.respond_to?(:pager)
        @owner.pager.quit_paging
      end
    end
  end
end
