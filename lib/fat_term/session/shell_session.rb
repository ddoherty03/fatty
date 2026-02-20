# frozen_string_literal: true

require "open3"
require "pty"
require "fileutils"
require "thread"

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
      @pty_queue = Queue.new
      @pty_thread = nil
      @pty_reader = nil
      @suppress_pty = false
    end

    def init(terminal:)
      resize_output!(terminal: terminal)
      []
    end

    def keymap_contexts
      if pager.paused?
        [:paging, :terminal]
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
        pager: pager,
      )
    end

    def update_key(ev, terminal:)
      key_str = "key=#{ev.key.inspect} ctrl=#{ev.ctrl?} meta=#{ev.meta?} raw=#{ev.raw.inspect}"
      FatTerm.log("ShellSession.update_key (unbound): #{key_str}", tag: :session)
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
      if pager_active?
        renderer.render_output(output, viewport: pager_viewport)
        # Reserve the last row of the output pane for a pager minibuffer.
        # For now it's informational; later it becomes a true minibuffer for
        # incremental search, etc.
        renderer.render_pager_field(
          pager_field,
          row: screen.output_rect.rows - 1,
          role: :status_info,
        )
      else
        renderer.render_output(output, viewport: viewport)
        renderer.render_input_field(@field)
        renderer.restore_cursor(@field)
      end
    end

    # Save any state we want saved on quit, error, etc.
    def persist!(terminal:)
      return unless @history.respond_to?(:save!)

      FatTerm.log("ShellSession.persist!: saving history", tag: :session)
      @history.save!
    rescue => e
      FatTerm.log("ShellSession.persist!: failed to save history: #{e.class}: #{e.message}", tag: :error)
    end

    # Called by Terminal#go when there is no input message (poll wake-up).
    # Returns true if any visible state changed (dirty).
    def tick(terminal:)
      FatTerm.debug("tick: autoscroll?=#{pager.autoscroll?} top=#{viewport.top} total=#{output.lines.length}")
      buf    = +""
      chunks = 0
      bytes  = 0

      while chunks < 50 && bytes < 64 * 1024
        item = @pty_queue.pop(true) rescue nil
        break unless item.is_a?(String)

        buf << item
        chunks += 1
        bytes  += item.bytesize
      end
      moved = pager.autoscroll? ? pager.autoscroll_step : false
      appended =
        if buf.empty? || @suppress_pty
          false
        else
          append_output(buf)
          true
        end

      moved || appended
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

    def apply_action(action, args, ev, terminal:, env:)
      case action
      when :accept_line
        accept_line(terminal)
      when :interrupt
        if @pty_pid
          begin
            Process.kill("INT", @pty_pid)
          rescue Errno::ESRCH
            @pty_pid = nil
          end
          []
        else
          [[:terminal, :quit]]
        end
      when :interrupt_if_empty
        if @field.empty?
          if @pty_pid
            begin
              Process.kill("INT", @pty_pid)
            rescue Errno::ESRCH
              @pty_pid = nil
            end
            []
          else
            [[:terminal, :quit]]
          end
        else
          @field.act_on(:delete_char_forward, env: env)
          []
        end
      when :clear_output
        reset_output!
        []
      when :quit_paging
        pager.act_on(:quit_paging, env: env)
        stop_command_output!
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
      else
        begin
          if pager_action?(action)
            pager.act_on(action, *args, env: env)
          else
            @field.act_on(action, *args, env: env)
          end
        rescue FatTerm::ActionError => e
          return [alert_cmd(:error, e.message, ev: ev)]
        end
        []
      end
    end

    def pager_action?(action)
      spec = FatTerm::Actions.lookup(action) # or whatever you have
      spec && spec[:on] == :pager
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
        # Always start a new command in a clean paging baseline.
        reset_for_command!
        anchor = output.lines.length
        pager.begin_command!(anchor: anchor)
        append_output("$ #{line}\n")
        @suppress_pty = false
        if @on_accept
          # callback is expected to return commands (or nil)
          Array(@on_accept.call(line, terminal: terminal, session: self))
        else
          @pty_thread = Thread.new do
            begin
              run_command_pty_stream(line) do |chunk|
                @pty_queue << chunk
              end
            rescue StandardError => ex
              @pty_queue << "#{ex.class}: #{ex}\n"
              @pty_queue << (ex.backtrace&.join("\n").to_s + "\n")
            end
          end
          [[:send, :alert, :clear, {}]]
        end
      end
    rescue Errno::ENOENT
      [[:send, :alert, :show, { level: :error, message: "Command not found (#{line})" }]]
    end

    def run_command_pty_stream(line)
      shell = ENV["SHELL"] || "/bin/sh"
      PTY.spawn(shell, "-c", line) do |r, _w, pid|
        @pty_pid = pid
        @pty_reader = r
        begin
          loop do
          chunk = r.readpartial(4096)
          yield chunk
        end
        rescue EOFError, Errno::EIO
          # normal end-of-pty
        ensure
          Process.wait(pid) rescue nil
          @pty_pid = nil
          @pty_reader = nil
        end
      end
    rescue Errno::ENOENT
      raise
    rescue StandardError => ex
      yield "#{ex.class}: #{ex}\n"
      yield(ex.backtrace.join("\n") + "\n") if ex.backtrace
      @pty_pid = nil
    end

    def stop_command_output!
      @suppress_pty = true

      # Drop anything already queued so the screen doesn't change after quitting.
      begin
        loop do
        @pty_queue.pop(true)
      end
      rescue ThreadError
        # queue empty
      end

      # Try to stop the child, then close the reader to force the PTY loop to exit.
      if @pty_pid
        begin
          Process.kill("INT", @pty_pid)
        rescue Errno::ESRCH
          @pty_pid = nil
        end
      end

      if @pty_reader
        begin
          @pty_reader.close
        rescue StandardError
          # ignore
        ensure
          @pty_reader = nil
        end
      end
      nil
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
