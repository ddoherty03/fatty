# frozen_string_literal: true

require "open3"

module Fatty
  class ShellSession < OutputSession
    action_on :session

    attr_reader :field, :history

    def initialize(prompt: "sh> ", on_accept: nil, completion_proc: nil, history_ctx: nil, history_path: :default)
      super(
        keymap: Keymaps.emacs,
        views: [
          Fatty::OutputView.new(z: 0),
          Fatty::InputView.new(z: 10),
          Fatty::CursorView.new(z: 100),
        ]
      )
      @history = Fatty::History.for_path(history_path)
      @field = Fatty::InputField.new(
        prompt: prompt,
        history: @history,
        completion_proc: completion_proc,
        history_kind: :command,
        history_ctx: history_ctx,
      )

      @on_accept = on_accept
      @completion_proc = completion_proc
    end

    #########################################################################################
    # Framework and Session Hooks
    #########################################################################################

    def init(terminal:)
      super
      resize_output!
      []
    end

    def update_key(ev)
      return [] unless ev.is_a?(Fatty::KeyEvent)

      key_str = "key=#{ev} raw=#{ev.raw}"
      Fatty.debug("ShellSession.update_key: #{key_str}", tag: :session)
      case ev.key
      when :resize
        Command.terminal(:handle_resize)
      when :enter, :return
        # safety: if somehow not bound, still accept
        handle_action(:submit_line, event: ev)
      else
        alert_cmd(:warn, "Unbound key: #{ev} (edit config in 'keybindings.yml' to bind)", ev: ev)
      end
    end

    def view(renderer:)
      if pager_active?
        ::Curses.curs_set(0)
        viewport = pager_status_viewport(renderer.screen)
        highlights = pager.search_visible_highlights(viewport: viewport)

        renderer.render_output(output, viewport: viewport, highlights: highlights)
        renderer.render_pager_field(
          pager_field,
          row: renderer.screen.output_rect.rows - 1,
          role: :pager_status,
        )
      else
        ::Curses.curs_set(1)
        renderer.render_output(output, viewport: pager_viewport, highlights: nil)
        renderer.render_input_field(field)
        renderer.restore_cursor(field)
      end
    end

    def keymap_contexts
      pager_active? ? [:paging, :terminal] : [:input, :text, :terminal]
    end

    def pager_status_viewport(screen)
      vp = pager_viewport.dup
      vp.height = [screen.output_rect.rows - 1, 1].max
      vp
    end

    # Save any state we want saved on quit, error, etc.
    def persist!
      return unless @history.respond_to?(:save!)

      Fatty.debug("ShellSession#persist!: saving history", tag: :history)
      @history.save!
    rescue => e
      Fatty.error("ShellSession#persist!: failed to save history: #{e.class}: #{e.message}", tag: :history)
    end

    # Called by Terminal#go on every loop iteration.
    # Returns true if any visible state changed (dirty).
    def tick
      dirty = false
      # Animated autoscroll (e.g. after M-s in paging mode).
      if pager.autoscroll?
        step = [(viewport.height * 3) / 4, 1].max
        dirty ||= pager.autoscroll_step?(max_lines: step)
      end
      dirty
    end

    ############################################################################################
    # Actions
    ############################################################################################

    def action_env(event:)
      Fatty::ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        buffer: @field.buffer,
        field: @field,
        pager: pager,
      )
    end

    desc "Pass the current shell input line to the proc"
    action :submit_line do
      line = @field.accept_line.to_s.strip
      return [] if line.empty?

      Fatty.info("ShellSession: accept_line: #{line}")
      case line
      when "exit", "quit"
        Command.terminal(:quit)
      when "clear"
        reset_output!
        Command.session(:alert, :clear)
      else
        # Here is where command lines are handled.  The @on_accept proc can
        # return a String or an Array of Strings, and they are forwarded to
        # the OutputSession to be rendered in the output pane.
        reset_for_command!
        anchor = output.lines.length
        pager.begin_command!(anchor: anchor)

        commands = [Command.session(:output, :append, text: "$ #{line}\n", follow: true)]
        result =
          if @on_accept
            @on_accept.call(line, accept_env)
          else
            run_default_command(line)
          end
        if result
          text = Array(result).compact.join
          commands << Command.session(:output, :append, text: text, follow: true) unless text.empty?
        else
          commands << alert_cmd(:error, "Command not found: #{line}")
        end
        commands
      end
    end

    desc "Accept the current shell input line and switch output to scrolling"
    action :submit_and_scroll do
      before = output.lines.length
      cmds = submit_line
      pager.paging_to_scrolling if output.lines.length > before
      cmds
    end

    desc "Interrupt scrolling, otherwise quit Fatty"
    action :interrupt do
      if pager.mode == :scrolling
        pager.quit_paging
        []
      else
        Command.terminal(:quit)
      end
    end

    desc "Quit if input is empty, otherwise delete forward"
    action :interrupt_if_empty do
      if pager.mode == :scrolling
        pager.quit_paging
        []
      elsif @field.empty?
        Command.terminal(:quit)
      else
        @field.act_on(:delete_char_forward, env: action_env(event: nil))
        []
      end
    end

    desc "Clear shell output"
    action :clear_output do
      reset_output!
      []
    end

    desc "Cycle to the next theme"
    action :cycle_theme do
      Command.terminal(:cycle_theme)
    end

    desc "Choose a theme from a popup"
    action :choose_theme do
      Command.terminal(:choose_theme)
    end

    desc "Add a digit to the current numeric prefix"
    action :prefix_digit do |digit|
      counter.push_digit(digit)
      []
    end

    desc "Complete the current input prefix"
    action :complete do
      with_virtual_suffix_sync do
        @field.cycle_completion!
        []
      end
    end

    desc "Open completion popup"
    action :completion_popup do
      with_virtual_suffix_sync do
        candidates = @field.popup_completion_candidates

        if candidates.empty?
          []
        elsif candidates.length == 1
          apply_completion(candidates.first, range: @field.popup_completion_range)
        else
          @completion_range = @field.popup_completion_range
          # NOTE: we don't pass a matcher so that the default_matcher is used.
          popup = Fatty::PopUpSession.new(
            source: candidates,
            kind: :completion,
            title: "Completions",
            prompt: "Complete: ",
            order: :as_given,
            selection: :top,
            initial_query: @field.popup_completion_query.to_s,
          )
          [[:terminal, :push_modal, popup]]
          Command.terminal(:push_modal, session: popup)
        end
      end
    end

    desc "Search pager forward"
    action :pager_search_forward do
      regex = consume_search_regex_flag
      searcher = Fatty::SearchSession.new(direction: :forward, regex: regex, history: @history)
      Command.terminal(:push_modal, session: searcher)
    end

    desc "Search pager backward"
    action :pager_search_backward do
      regex = consume_search_regex_flag
      searcher = Fatty::SearchSession.new(direction: :backward, regex: regex, history: @history)
      Command.terminal(:push_modal, session: searcher)
    end

    desc "Start incremental pager search forward"
    action :pager_isearch_forward do
      isearcher = Fatty::ISearchSession.new(direction: :forward, history: @history, last_pattern: pager.search_pattern)
      Command.terminal(:push_modal, session: isearcher)
    end

    desc "Start incremental pager search backward"
    action :pager_isearch_backward do
      isearcher = Fatty::ISearchSession.new(direction: :backward, history: @history, last_pattern: pager.search_pattern)
      Command.terminal(:push_modal, session: isearcher)
    end

    desc "Repeat pager search forward"
    action :pager_search_next do
      handle_search_result(pager.search_repeat_next!)
    end

    desc "Repeat pager search backward"
    action :pager_search_prev do
      handle_search_result(pager.search_repeat_prev!)
    end

    desc "Open command history search"
    action :history_search do
      src = ->(_q = nil) { @history.entries.select(&:command?).last(500).map(&:text) }
      hist_searcher =
        Fatty::PopUpSession.new(
          source: src,
          kind: :history_search,
          title: "History",
          prompt: "I-search: ",
          order: :as_given,
          selection: :bottom,
          initial_query: @field.buffer.text,
        )
      Command.terminal(:push_modal, session: hist_searcher)
    end

    #########################################################################################
    # Completion
    #########################################################################################

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

    def accept_env
      Fatty::AcceptEnv.new(session: self)
    end

    def update_cmd(name, payload)
      commands = []
      case name
      when :popup_result
        commands.concat(update_popup_result(payload))
      when :pager_search_set
        commands.concat(update_pager_search_set(payload))
      when :pager_search_step
        commands.concat(update_pager_search_step(payload))
      when :pager_isearch_update
        commands.concat(update_pager_isearch_update(payload))
      when :pager_isearch_step
        commands.concat(update_pager_isearch_step(payload))
      when :pager_isearch_cancel
        pager.isearch_cancel!
        commands << Command.session(:isearch, :isearch_set_failed, failed: false)
      when :pager_isearch_commit
        commands.concat(update_pager_isearch_commit(payload))
      when :paste
        text = payload.fetch(:text, "").to_s
        env = action_env(event: nil)
        field.act_on(:paste, text, env: env)
      end
      commands
    end

    def handle_action(action, args, event:)
      which =
        if event&.respond_to?(:key)
          event.key.inspect
        elsif event&.respond_to?(:mouse)
          event.mouse.inspect
        end
      Fatty.debug("ShellSession#handle_action: #{which}", tag: :keymap)
      env = action_env(event: event)
      apply_action(action, args, event, env: env)
    end

    # Centralized dispatch: actions declare their target (:buffer/:field/:pager)
    # and Fatty::Actions routes through ActionEnvironment.
    def apply_action(action, args, ev, env:)
      @field.reset_completion_state! unless action.to_sym == :complete
      defn = Fatty::Actions.lookup(action)
      result = Fatty::Actions.call(action, env, *args)
      if defn && [:field, :buffer].include?(defn[:on])
        @field.sync_virtual_suffix!
      end
      result.is_a?(Array) ? result : []
    rescue Fatty::ActionError => e
      [alert_cmd(:error, e.message, ev: ev)]
    end

    def run_default_command(line)
      Command.session(:output, :append, text: "$ #{line}\n", follow: true)
      out, status = Open3.capture2e(line)
      out << "\n[exit #{status.exitstatus}]\n" if status&.exitstatus && status.exitstatus != 0
      out
    rescue Errno::ENOENT
      nil
    end

    def consume_search_regex_flag
      regex = false
      if counter.digits.to_s == "4"
        regex = true
        counter.clear!
      end
      regex
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
      Command.session(:alert, :show, level: level, message: message, details: details)
    end

    def update_popup_result(payload)
      commands = []

      case payload[:kind]&.to_sym
      when :history_search
        item = payload.fetch(:item, "").to_s
        env = action_env(event: nil)

        with_virtual_suffix_sync do
          Fatty::Actions.call(:replace, env, item)
        end
      when :completion
        apply_completion(payload.fetch(:item, "").to_s, range: @completion_range)
        @completion_range = nil
      end

      commands
    end

    def update_pager_search_set(payload)
      pattern = payload.fetch(:pattern, "").to_s
      regex = !!payload[:regex]
      direction = (payload[:direction] || :forward).to_sym
      result = pager.search_set!(pattern: pattern, regex: regex, direction: direction)

      handle_search_result(result)
    end

    def update_pager_search_step(payload)
      direction = (payload[:direction] || :forward).to_sym
      result = pager.search_step!(direction: direction)

      handle_search_result(result)
    end

    def update_pager_isearch_update(payload)
      pattern = payload.fetch(:pattern, "").to_s
      direction = (payload[:direction] || :forward).to_sym
      result = pager.isearch_update!(pattern: pattern, direction: direction)

      handle_search_result(result) +
        [Command.session(:isearch, :isearch_set_failed, failed: result[:status] != :moved)]
    end

    def update_pager_isearch_step(payload)
      direction = (payload[:direction] || :forward).to_sym
      result = pager.isearch_step!(direction: direction)

      handle_search_result(result) +
        [Command.session(:isearch, :isearch_set_failed, failed: result[:status] != :moved)]
    end

    def update_pager_isearch_commit(payload)
      pattern = payload.fetch(:pattern, "").to_s
      direction = (payload[:direction] || :forward).to_sym
      result = pager.isearch_commit!(pattern: pattern, direction: direction)

      handle_search_result(result) +
        [Command.session(:isearch, :isearch_set_failed, failed: false)]
    end

    def handle_search_result(result)
      return [] unless result.is_a?(Hash)

      case result[:status]
      when :boundary
        msg = result[:message].to_s
        msg = "Search reached boundary" if msg.empty?
        alert_cmd(:info, msg)
      when :not_found
        alert_cmd(:info, "No matches")
      else
        []
      end
    end
  end
end
