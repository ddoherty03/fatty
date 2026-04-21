# frozen_string_literal: true

require "open3"

module FatTerm
  class ShellSession < OutputSession
    attr_reader :field, :history

    def initialize(prompt: "sh> ", on_accept: nil, completion_proc: nil, history_ctx: nil, history_path: :default)
      super(
        keymap: Keymaps.emacs,
        views: [
          FatTerm::OutputView.new(z: 0),
          FatTerm::InputView.new(z: 10),
          FatTerm::CursorView.new(z: 100),
        ]
      )
      @history = FatTerm::History.for_path(history_path)
      @field = FatTerm::InputField.new(
        prompt: prompt,
        history: @history,
        completion_proc: completion_proc,
        history_kind: :command,
        history_ctx: history_ctx,
      )

      @on_accept = on_accept
      @completion_proc = completion_proc

      # Default command runner when no on_accept proc is provided.
      # This is intentionally synchronous and capture-based (no PTY streaming).
      @on_accept ||= lambda do |line, terminal:, session:|
        out, status = Open3.capture2e(line)
        session.append_output(out, follow: true)
        if status && status.exitstatus && status.exitstatus != 0
          session.append_output("[exit #{status.exitstatus}]\n", follow: true)
        end
        [[:send, :alert, :clear, {}]]
        rescue Errno::ENOENT
          [[:send, :alert, :show, { level: :error, message: "Command not found (#{line})" }]]
      end
    end

    def init(terminal:)
      resize_output!(terminal: terminal)
      []
    end

    def keymap_contexts
      if pager_active?
        [:paging, :terminal]
      else
        [:input, :terminal]
      end
    end

    def action_env(terminal:, event:)
      FatTerm::ActionEnvironment.new(
        session: self,
        terminal: terminal,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
        pager: pager,
      )
    end

    def update_key(ev, terminal:)
      return [] unless ev.is_a?(FatTerm::KeyEvent)

      key_str = "key=#{ev} raw=#{ev.raw}"
      FatTerm.debug("ShellSession.update_key: #{key_str}", tag: :session)
      case ev.key
      when :resize
        [[:terminal, :handle_resize]]
      when :enter, :return
        # safety: if somehow not bound, still accept
        accept_line(terminal)
      else
        [alert_cmd(:info, "Unbound key: #{ev} (edit config in 'keybindings.yml' to bind)", ev: ev)]
      end
    end

    def view(screen:, renderer:, terminal:)
      if pager_active?
        ::Curses.curs_set(0)
        highlights = pager.search_visible_highlights(viewport: pager_viewport)
        renderer.render_output(output, viewport: pager_viewport, highlights: highlights)
        renderer.render_pager_field(
          pager_field,
          row: screen.output_rect.rows - 1,
          role: :pager_status,
        )
      else
        ::Curses.curs_set(1)
        renderer.render_output(output, viewport: pager_viewport, highlights: nil)
        renderer.render_input_field(field)
        renderer.restore_cursor(field)
      end
    end

    # Save any state we want saved on quit, error, etc.
    def persist!(terminal:)
      return unless @history.respond_to?(:save!)

      FatTerm.debug("ShellSession#persist!: saving history", tag: :history)
      @history.save!
    rescue => e
      FatTerm.error("ShellSession#persist!: failed to save history: #{e.class}: #{e.message}", tag: :history)
    end

    # Called by Terminal#go on every loop iteration.
    # Returns true if any visible state changed (dirty).
    def tick(terminal:)
      dirty = false
      # Animated autoscroll (e.g. after M-s in paging mode).
      if pager.autoscroll?
        step = [viewport.height / 8, 1].max
        dirty ||= pager.autoscroll_step?(max_lines: step)
      end
      dirty
    end

    def completion_candidates
      path_candidates = @field.path_completion_candidates
      return path_candidates if path_candidates.any?

      return [] unless @completion_proc

      prefix = completion_prefix
      Array(@completion_proc.call(@field.buffer))
        .compact
        .map(&:to_s)
        .reject(&:empty?)
        .select { |s| s.start_with?(prefix) }
        .uniq
    end

    def completion_prefix
      @field.buffer.completion_prefix
    end

    def completion_prefix_range
      buffer = @field.buffer
      prefix = completion_prefix
      finish = buffer.cursor
      start = finish - prefix.length
      start...finish
    end

    def longest_common_prefix(strings)
      result = ""
      if strings.any?
        result = strings.first.to_s.dup
        strings.drop(1).each do |s|
          other = s.to_s
          i = 0
          max = [result.length, other.length].min
          i += 1 while i < max && result[i] == other[i]
          result = result[0...i]
          break if result.empty?
        end
      end
      result
    end

    def apply_completion_prefix(prefix)
      text = prefix.to_s
      commands = []
      unless text.empty?
        buffer = @field.buffer
        buffer.replace_range(completion_prefix_range, text)
      end
      commands
    end

    def apply_completion(candidate, range: nil)
      candidate = candidate.to_s
      return [] if candidate.empty?

      buffer = @field.buffer
      target = range || buffer.completion_replace_range
      old_text = buffer.text.dup
      old_end = target.end
      append_space =
        !candidate.match?(/\s\z/) &&
        (old_end >= old_text.length || old_text[old_end]&.match?(/\s/))
      inserted = append_space ? "#{candidate} " : candidate
      buffer.replace_range(target, inserted)
      []
    end

    private

    def update_cmd(name, payload, terminal:)
      cmds = []
      case name
      when :popup_result
        case payload[:kind]&.to_sym
        when :history_search
          item = payload.fetch(:item, "").to_s
          env = action_env(terminal: terminal, event: nil)
          with_virtual_suffix_sync do
            FatTerm::Actions.call(:replace, env, item)
          end
        when :theme_chooser
          theme = payload.fetch(:item).to_sym
          @theme_popup_restore = nil
          cmds << [:terminal, :set_theme, theme]
          cmds << [:send, :alert, :show, { level: :info, message: "Theme: #{theme}" }]
        when :completion
          apply_completion(payload.fetch(:item, "").to_s, range: @completion_range)
          @completion_range = nil
        end
      when :popup_changed
        if payload[:kind]&.to_sym == :theme_chooser
          theme = payload.fetch(:item).to_sym
          cmds << [:terminal, :set_theme, theme]
        end
      when :popup_cancelled
        if payload[:kind]&.to_sym == :theme_chooser && @theme_popup_restore
          cmds << [:terminal, :set_theme, @theme_popup_restore]
          @theme_popup_restore = nil
        end
      when :pager_search_set
        pattern = payload.fetch(:pattern, "").to_s
        regex = !!payload[:regex]
        direction = (payload[:direction] || :forward).to_sym
        result = pager.search_set!(pattern: pattern, regex: regex, direction: direction)
        cmds.concat(handle_search_result(result))
      when :pager_search_step
        direction = (payload[:direction] || :forward).to_sym
        result = pager.search_step!(direction: direction)
        cmds.concat(handle_search_result(result))
      when :pager_isearch_update
        pattern = payload.fetch(:pattern, "").to_s
        direction = (payload[:direction] || :forward).to_sym
        result = pager.isearch_update!(pattern: pattern, direction: direction)
        cmds.concat(handle_search_result(result))
        cmds << [:send, :isearch, :isearch_set_failed, { failed: result[:status] != :moved }]
      when :pager_isearch_step
        direction = (payload[:direction] || :forward).to_sym
        result = pager.isearch_step!(direction: direction)
        cmds.concat(handle_search_result(result))
        cmds << [:send, :isearch, :isearch_set_failed, { failed: result[:status] != :moved }]
      when :pager_isearch_cancel
        pager.isearch_cancel!
        cmds << [:send, :isearch, :isearch_set_failed, { failed: false }]
      when :pager_isearch_commit
        pattern = payload.fetch(:pattern, "").to_s
        direction = (payload[:direction] || :forward).to_sym
        result = pager.isearch_commit!(pattern: pattern, direction: direction)
        cmds.concat(handle_search_result(result))
        cmds << [:send, :isearch, :isearch_set_failed, { failed: false }]
      when :paste
        text = payload.fetch(:text, "").to_s
        env = action_env(terminal: terminal, event: nil)
        field.act_on(:paste, text, env: env)
      end
      cmds
    end

    def handle_action(action, args, terminal:, event:)
      which =
        if event&.respond_to?(:key)
          event.key.inspect
        elsif event&.respond_to?(:mouse)
          event.mouse.inspect
        end
      FatTerm.debug("ShellSession#handle_action: #{which}", tag: :keymap)
      env = action_env(terminal: terminal, event: event)
      apply_action(action, args, event, terminal: terminal, env: env)
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
      when :prefix_digit
        counter.push_digit(args.first)
        []
      when :clear_output
        reset_output!
        []
      when :cycle_theme
        [[:terminal, :cycle_theme]]
      when :choose_theme
        current = FatTerm::Colors::ThemeManager.current
        names = FatTerm::Colors::ThemeManager.theme_names
        ordered = [current] + (names - [current])
        @theme_popup_restore = current
        popup = FatTerm::PopUpSession.new(
          source: ordered,
          kind: :theme_chooser,
          title: "Themes",
          prompt: "Theme: ",
          selection: :top,
        )
        [[:terminal, :push_modal, popup]]
      when :complete
        with_virtual_suffix_sync do
          @field.cycle_completion!
          []
        end
      when :completion_popup
        with_virtual_suffix_sync do
          candidates = @field.popup_completion_candidates
          if candidates.empty?
            []
          elsif candidates.length == 1
            apply_completion(candidates.first, range: @field.popup_completion_range)
          else
            @completion_range = @field.popup_completion_range
            popup = FatTerm::PopUpSession.new(
              source: candidates,
              kind: :completion,
              title: "Completions",
              prompt: "Complete: ",
              order: :as_given,
              selection: :top,
              initial_query: @field.popup_completion_query.to_s,
              matcher: ->(item, q) { item.to_s.start_with?(q.to_s) },
            )
            [[:terminal, :push_modal, popup]]
          end
        end
      when :history_search
        # Oldest -> newest, so newest appears at the bottom of the popup.
        src = ->(_q = nil) { @history.entries.select(&:command?).last(500).map(&:text) }
        FatTerm.debug("ShellSession#apply_action: history_search: building popup", tag: :session)
        popup = FatTerm::PopUpSession.new(
          source: src,
          kind: :history_search,
          title: "History",
          prompt: "I-search: ",
          order: :as_given,
          selection: :bottom,
          initial_query: @field.buffer.text,
        )
        [[:terminal, :push_modal, popup]]
      when :pager_search_forward
        regex = consume_search_regex_flag
        [[:terminal, :push_modal, FatTerm::SearchSession.new(direction: :forward, regex: regex, history: @history)]]
      when :pager_search_backward
        regex = consume_search_regex_flag
        [[
           :terminal,
           :push_modal,
           FatTerm::SearchSession.new(direction: :backward, regex: regex, history: @history)
         ]]
      when :pager_isearch_forward
        [[
           :terminal,
           :push_modal,
           FatTerm::ISearchSession.new(direction: :forward, history: @history, last_pattern: pager.search_pattern)
         ]]
      when :pager_isearch_backward
        [[
           :terminal,
           :push_modal,
           FatTerm::ISearchSession.new(direction: :backward, history: @history, last_pattern: pager.search_pattern)
         ]]
      when :pager_search_next
        result = pager.search_repeat_next!
        handle_search_result(result)
      when :pager_search_prev
        result = pager.search_repeat_prev!
        handle_search_result(result)
      else
        begin
          # Centralized dispatch: actions declare their target (:buffer/:field/:pager)
          # and FatTerm::Actions routes through ActionEnvironment.
          with_virtual_suffix_sync do
            @field.reset_completion_cycle!
            FatTerm::Actions.call(action, env, *args)
          end
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
        # Always start a new command in a clean paging baseline.
        reset_for_command!
        anchor = output.lines.length
        pager.begin_command!(anchor: anchor)
        append_output("$ #{line}\n", follow: true)
        # @on_accept callback is expected to return commands (or nil)
        # Array(@on_accept.call(line, terminal: terminal, session: self))
        result =
          if @on_accept
            @on_accept.call(line, terminal: terminal, session: self)
          else
            run_default_command(line)
          end
        # Normalize result:
        # - Array-of-commands => return it
        # - String output     => append + return alert clear
        # - nil               => just return alert clear
        if result.is_a?(Array) && result.first.is_a?(Array) && result.first.first.is_a?(Symbol)
          result
        else
          out = result.to_s
          append_output(out, follow: true) unless out.empty?
          [[:send, :alert, :clear, {}]]
        end
      end
    rescue Errno::ENOENT
      [[:send, :alert, :show, { level: :error, message: "Command not found (#{line})" }]]
    end

    def run_default_command(line)
      out, status = Open3.capture2e(line)
      # optional: include exit status line
      out << "\n[exit #{status.exitstatus}]\n" if status && status.exitstatus && status.exitstatus != 0
      out
    rescue Errno::ENOENT
      "Command not found: #{line}\n"
    end

    def consume_search_regex_flag
      regex = false
      if counter.digits.to_s == "4"
        regex = true
        counter.clear!
      end
      regex
    end

    def handle_search_result(result)
      return unless result.is_a?(Hash)

      case result[:status]
      when :boundary
        msg = result[:message].to_s
        msg = "Search reached boundary" if msg.empty?
        [[:send, :alert, :show, { level: :info, message: msg }]]
      when :not_found
        [[:send, :alert, :show, { level: :info, message: "No matches" }]]
      else
        []
      end
    end

    def with_virtual_suffix_sync
      @field.sync_virtual_suffix!
      result = yield
      @field.sync_virtual_suffix!
      result
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
