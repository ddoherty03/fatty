# frozen_string_literal: true

require "open3"
require 'fileutils'

module FatTerm
  # Minimal interactive shell-like session.
  #
  # Responsibilities:
  #   - maintain input field + output buffer + viewport
  #   - execute shell commands on Enter
  #   - emit alert commands instead of owning alert state
  class ShellSession < Session
    attr_reader :output, :field, :viewport, :keymap

    def initialize(prompt: "sh> ", history_path: nil)
      super(views: [
              FatTerm::Views::OutputView.new(z: 0),
              FatTerm::Views::InputView.new(z: 10),
              FatTerm::Views::CursorView.new(z: 100),
            ])
      @output   = FatTerm::OutputBuffer.new
      @history  = FatTerm::History.new(path: history_path || default_history_path)
      @field    = FatTerm::InputField.new(prompt: prompt, history: @history)
      @viewport = FatTerm::Viewport.new(height: 10)
      @keymap   = FatTerm::Keymaps.emacs
    end

    def default_history_path
      base = ENV["XDG_STATE_HOME"] || File.join(Dir.home, ".local", "state")
      dir  = File.join(base, "fat_term")
      FileUtils.mkdir_p(dir)
      File.join(dir, "history")
    end

    def init(terminal:)
      @viewport.height = terminal.screen.output_rect.rows
      []
    end

    def update_key(ev, terminal:)
      handle_key(ev, terminal:)
    end

    private

    def handle_key(ev, terminal:)
      # Resize is delivered as a KeyEvent(:resize)
      if ev.key == :resize
        handle_resize(terminal)
        return []
      end

      action = resolve_action(ev)

      # Not bound? Printable => insert.
      result = nil
      if action.nil?
        if ev.text && !ev.text.empty? && ev.text != "\n" && ev.text != "\r"
          @field.act_on(:insert, ev.text)
          result = []
        else
          # Unmapped and not printable ⇒ surface to user (don’t silently ignore).
          result = [alert_cmd(:info, "Unbound key: #{ev}", ev: ev)]
        end
      else
        result = apply_action(action, ev, terminal:)
      end
      result
    end

    def resolve_action(ev)
      if paging_mode?
        @keymap.resolve(ev, contexts: :paging) || @keymap.resolve(ev, contexts: :input)
      else
        @keymap.resolve(ev, contexts: :input)
      end
    end

    def paging_mode?
      lines = @output.lines
      return false if lines.length <= @viewport.height

      !@viewport.at_bottom?(lines.length)
    end

    def apply_action(action, ev, terminal:)
      case action
      when :accept_line
        return accept_line(terminal)
      when :interrupt
        return [[:terminal, :quit]]
      when :interrupt_if_empty
        return [[:terminal, :quit]] if @field.empty?

        @field.act_on(:delete_char_forward)
        return []

        # Viewport actions
      when :page_up
        @viewport.page_up(@output.lines) and return []
      when :page_down
        @viewport.page_down(@output.lines) and return []
      when :scroll_up
        @viewport.scroll_up(@output.lines) and return []
      when :scroll_down
        @viewport.scroll_down(@output.lines) and return []
      when :page_top
        @viewport.page_top and return []
      when :page_bottom
        @viewport.page_bottom(@output.lines) and return []
      end
      @viewport.clamp!(@output.lines)

      # Editor action (buffer/field)
      begin
        @field.act_on(action)
      rescue FatTerm::ActionError => e
        return [alert_cmd(:error, e.message, ev: ev)]
      end

      []
    end

    def accept_line(terminal)
      line = @field.accept_line.to_s.strip
      return [] if line.empty?

      # Built-ins
      case line
      when "exit", "quit"
        return [[:terminal, :quit]]
      when "clear"
        @output.lines.clear
        @viewport.reset
        return [[:send, :alert, :clear, {}]]
      end

      at_bottom = @viewport.at_bottom?(@output.lines.length)
      ntrim = @output.append("$ #{line}\n")
      @viewport.adjust_for_trim(ntrim)

      begin
        out, _status = Open3.capture2e(line)
        ntrim2 = @output.append(out)
        @viewport.adjust_for_trim(ntrim2)
        @viewport.scroll_to_bottom(@output.lines) if at_bottom
        [[:send, :alert, :clear, {}]]
      rescue Errno::ENOENT
        [[:send, :alert, :show, { level: :error, message: "Command not found (#{line})" }]]
      end
    end

    def alert_cmd(level, message, ev: nil)
      details =
        if ev
          {
            key: ev.key,
            ctrl: ev.respond_to?(:ctrl?) ? ev.ctrl? : ev.ctrl,
            meta: ev.respond_to?(:meta?) ? ev.meta? : ev.meta,
            shift: ev.respond_to?(:shift?) ? ev.shift? : ev.shift,
            text: ev.text
          }
        else
          {}
        end

      # This assumes your Terminal dispatch layer already knows how to route
      # :send messages to pinned sessions by name (you likely already have this).
      [:send, :alert, :show, { level: level, message: message, details: details }]
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
