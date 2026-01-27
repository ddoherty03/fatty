# frozen_string_literal: true

require "open3"

module FatTerm
  module Sessions
    # Minimal interactive shell-like session.
    #
    # Responsibilities:
    #   - maintain input field + output buffer + viewport
    #   - execute shell commands on Enter
    #   - emit alert commands instead of owning alert state
    class ShellSession < Session
      attr_reader :output, :field, :viewport

      def initialize(prompt: "sh> ")
        super(views: [])

        @output = FatTerm::OutputBuffer.new
        @field  = FatTerm::InputField.new(prompt: prompt)

        # Viewport height depends on screen; initialize to something sane and
        # refresh in #init.
        @viewport = FatTerm::Viewport.new(height: 10)
      end

      def init(terminal:)
        @viewport.height = terminal.screen.output_rect.rows
        [self, []]
      end

      def update(message, terminal:)
        return handle_key(message, terminal:) if message.is_a?(FatTerm::KeyEvent)

        [self, []]
      end

      def view(screen:, renderer:, terminal:)
        renderer.render_output(@output, viewport: @viewport)
        renderer.render_input_field(@field)
        renderer.restore_cursor(@field)
      end

      private

      def handle_key(ev, terminal:)
        # Resize is delivered as a KeyEvent(:resize)
        if ev.key == :resize
          handle_resize(terminal)
          return [self, []]
        end

        # Quit
        if ev.ctrl? && ev.key == :c
          return [self, [[:terminal, :quit]]]
        end

        # Paging (very small initial set)
        case ev.key
        when :page_up
          @viewport.page_up(@output.lines)
          return [self, []]
        when :page_down
          @viewport.page_down(@output.lines)
          return [self, []]
        when :up
          @viewport.scroll_up(@output.lines)
          return [self, []]
        when :down
          @viewport.scroll_down(@output.lines)
          return [self, []]
        end

        case ev.key
        when :backspace
          @field.act_on(:delete_char_backward, count: 1)
          return [self, []]
        when :delete
          @field.act_on(:delete_char_forward, count: 1)
          return [self, []]
        when :left
          @field.act_on(:move_left, count: 1)
          return [self, []]
        when :right
          @field.act_on(:move_right, count: 1)
          return [self, []]
        when :home
          @field.act_on(:bol)
          return [self, []]
        when :end
          @field.act_on(:eol)
          return [self, []]
        when :enter
          return accept_line(terminal)
        end

        # Self-insert
        if ev.text && !ev.text.empty? && ev.text != "\n" && ev.text != "\r"
          @field.act_on(:insert, ev.text)
        end

        [self, []]
      end

      def accept_line(terminal)
        line = @field.accept_line.to_s.strip
        return [self, []] if line.empty?

        # Built-ins
        case line
        when "exit", "quit"
          return [self, [[:terminal, :quit]]]
        when "clear"
          @output.lines.clear
          @viewport.reset
          return [self, [[:send, :alert, :clear, {}]]]
        end

        at_bottom = @viewport.at_bottom?(@output.lines.length)
        ntrim = @output.append("$ #{line}\n")
        @viewport.adjust_for_trim(ntrim)

        begin
          out, _status = Open3.capture2e(line)
          ntrim2 = @output.append(out)
          @viewport.adjust_for_trim(ntrim2)
          @viewport.scroll_to_bottom(@output.lines) if at_bottom
          [self, [[:send, :alert, :clear, {}]]]
        rescue Errno::ENOENT
          [self, [[:send, :alert, :show, { level: :error, message: "Command not found" }]]]
        end
      end

      def handle_resize(terminal)
        # Recompute layout
        rows = ::Curses.lines
        cols = ::Curses.cols
        terminal.screen.resize(rows: rows, cols: cols)
        terminal.renderer.context.apply_layout(terminal.screen)
        terminal.renderer.screen = terminal.screen
        @viewport.height = terminal.screen.output_rect.rows
        @viewport.clamp!(@output.lines)
      end
    end
  end
end
