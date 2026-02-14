# frozen_string_literal: true

require "open3"
require "fileutils"

module FatTerm
  class ShellSession < OutputSession
    attr_reader :field

    def initialize(prompt: "sh> ", on_accept: nil)
      super(
        keymap: Keymaps.emacs,
        views: [
          FatTerm::OutputView.new(z: 0),
          FatTerm::InputView.new(z: 10),
          FatTerm::CursorView.new(z: 100),
        ]
      )
      @history = FatTerm::History.new # you said History now uses config defaults
      @field   = FatTerm::InputField.new(prompt: prompt, history: @history)
      @on_accept = on_accept
    end

    def init(terminal:)
      resize_output!(terminal: terminal)
      []
    end

    def keymap_contexts
      if paging_mode?
        [:paging, :input, :terminal]
      else
        [:input, :terminal]
      end
    end

    def action_env(terminal:, event:)
      FatTerm::ActionEnvironment.new(
        session: self,
        terminal: terminal,
        event: event,
        buffer: @field.buffer,
        field: @field,
      )
    end

    def update_key(ev, terminal:)
      FatTerm.log("ShellSession.update_key (unbound): key=#{ev.key.inspect} ctrl=#{ev.ctrl?} meta=#{ev.meta?} raw=#{ev.raw.inspect}", tag: :session)
      case ev.key
      when :resize
        handle_resize(terminal)
        []
      when :enter, :return
        # safety: if somehow not bound, still accept
        accept_line(terminal)
      else
        [alert_cmd(:info, "Unbound key: #{ev} (edit config in 'keybindings.yml' to bind)", ev: ev)]
      end
    end

    def view(screen:, renderer:, terminal:)
      renderer.render_output(output, viewport: viewport)
      renderer.render_input_field(@field)
      renderer.restore_cursor(@field)
    end

    # Save any state we want saved on quit, error, etc.
    def persist!(terminal:)
      return unless @history.respond_to?(:save!)

      FatTerm.log("ShellSession.persist!: saving history", tag: :session)
      @history.save!
    rescue => e
      FatTerm.log("ShellSession.persist!: failed to save history: #{e.class}: #{e.message}", tag: :error)
    end

    private

    def update_cmd(name, payload, terminal:)
      case name
      when :popup_result
        item = payload.fetch(:item, "").to_s
        env = action_env(terminal: terminal, event: nil)
        @field.act_on(:replace, item, env: env)
      end
      []
    end

    def handle_action(action, args, terminal:, event:)
      FatTerm.log(
        "ShellSession.handle_action: action=#{action.inspect} args=#{args.inspect} key=#{event.key.inspect}",
        tag: :keymap,
      )
      env = action_env(terminal: terminal, event: event)
      apply_action(action, args, event, terminal: terminal, env: env)
    end

    def paging_mode?
      lines = output.lines
      viewport.clamp!(lines)
      return false if lines.length <= viewport.height

      !viewport.at_bottom?(lines.length)
    end

    def apply_action(action, args, ev, terminal:, env:)
      case action
      when :accept_line
        accept_line(terminal)
      when :interrupt
        [[:terminal, :quit]]
      when :interrupt_if_empty
        if @field.empty?
          [[:terminal, :quit]]
        else
          @field.act_on(:delete_char_forward, env: env)
          []
        end
      when :clear_output
        reset_output!
        []
      when :cycle_theme
        [[:terminal, :cycle_theme]]
      when :history_search
        src = -> do
          # Oldest -> newest, so newest appears at the bottom of the popup.
          @history.entries.last(500)
        end
        popup = FatTerm::PopUpSession.new(
          source: src,
          title: "History",
          prompt: "I-search: ",
          order: :as_given,
          selection: :bottom,
        )
        [[:terminal, :push_modal, popup]]
      when :page_up
        viewport.page_up(output.lines)
        []
      when :page_down
        viewport.page_down(output.lines)
        []
      when :scroll_up
        viewport.scroll_up(output.lines)
        []
      when :scroll_down
        viewport.scroll_down(output.lines)
        []
      when :page_top
        viewport.page_top
        []
      when :page_bottom
        viewport.page_bottom(output.lines)
        []
      else
        viewport.clamp!(output.lines)
        begin
          @field.act_on(action, *args, env: env)
        rescue FatTerm::ActionError => e
          return [alert_cmd(:error, e.message, ev: ev)]
        end
        []
      end
    end

    def accept_line(terminal)
      line = @field.accept_line.to_s.strip
      return [] if line.empty?

      FatTerm.info("ShellSession: accept_line: #{line}")
      case line
      when "exit", "quit"
        [[:terminal, :quit]]
      when "clear"
        reset_output!
        [[:send, :alert, :clear, {}]]
      else
        if @on_accept
          # callback is expected to return commands (or nil)
          Array(@on_accept.call(line, terminal: terminal, session: self))
        else
          # Default: run as a shell command, preserving viewport behavior via append_output.
          append_output("$ #{line}\n")
          out, _status = Open3.capture2e(line)
          append_output(out)
          [[:send, :alert, :clear, {}]]
        end
      end
    rescue Errno::ENOENT
      [[:send, :alert, :show, { level: :error, message: "Command not found (#{line})" }]]
    end

    def handle_resize(terminal)
      rows = ::Curses.lines
      cols = ::Curses.cols
      terminal.screen.resize(rows: rows, cols: cols)
      terminal.renderer.context.apply_layout(terminal.screen)
      terminal.renderer.screen = terminal.screen
      resize_output!(terminal: terminal)
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

      [:send, :alert, :show, { level: level, message: message, details: details }]
    end
  end
end
