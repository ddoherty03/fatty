# frozen_string_literal: true

require "open3"

module Fatty
  class ShellSession < Session
    action_on :session

    attr_reader :field, :history, :output_session, :on_accept

    def initialize(id: nil, prompt: "sh> ", on_accept: nil, completion_proc: nil, history_ctx: nil, history_path: :default)
      keymap = Keymaps.emacs
      super(
        id: :shell,
        keymap: keymap,
      )
      @history = Fatty::History.for_path(history_path)
      @output_session = OutputSession.new(keymap: keymap, history: @history)
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
    # Session Protocol
    #########################################################################################

    def init(terminal:)
      super
      output_session.init(terminal: terminal)
      [
        Command.terminal(:register_session, session: output_session),
        Command.session(output_session.id, :resize),
      ]
    end

    def update(command)
      log_update(command)
      commands =
        case command.action
        when :terminal_paste
          field.act_on(:paste, command.payload.fetch(:text, ""), env: action_env(event: nil))
          []
        when :popup_result
          apply_popup_result(command.payload)
        when :paste
          text = command.payload.fetch(:text, "").to_s
          env = action_env(event: nil)
          field.act_on(:paste, text, env: env)
          []
        when :key
          ev = command.payload.fetch(:event)
          if output_session.pager_active?
            Command.session(output_session.id, :key, event: ev)
          elsif ev.is_a?(Fatty::KeyEvent)
            action, args = resolve_action(ev)
            if action
              apply_action(action, args, event: ev)
            else
              case ev.key
              when :enter, :return
                apply_action(:submit_line, [], event: ev)
              else
                unrecognized_key_alert(ev)
              end
            end
          else
            []
          end
        else
          []
        end
      Array(commands)
    end

    def view
      Fatty.debug(
        "ShellSession#view output_session=" \
          "#{output_session.class}:#{output_session.object_id}",
        tag: :render,
      )
      output_session.view
      if input_suppressed?
        renderer.clear_input_field
      else
        renderer.render_input_field(field)
      end
    end

    #########################################################################################
    # Actions
    #########################################################################################

    desc "Pass the current input line to the on_accept proc or a shell"
    action :submit_line do
      line = @field.accept_line.to_s
      return [] if line.blank? && on_accept.nil?

      Fatty.info("ShellSession: accept_line: #{line}")
      case line
      when "exit", "quit"
        Command.terminal(:quit)
      when "clear"
        [
          Command.session(output_session.id, :clear),
          Command.session(:alert, :clear),
        ]
      else
        commands = []
        env = accept_env
        terminal.apply_command(Command.session(output_session.id, :begin_command))
        result =
          if @on_accept
            @on_accept.call(line, env)
          else
            run_default_command(line)
          end
        commands.concat(env.commands)
        if result.is_a?(String)
          commands << Command.session(output_session.id, :append, text: result, follow: true)
        elsif result.is_a?(Fatty::Command)
          commands << result
        elsif result.is_a?(Array)
          commands.concat(result.grep(Fatty::Command))
        elsif result
          commands << Command.session(output_session.id, :append, text: result.to_s, follow: true)
        end
        commands << Command.session(output_session.id, :finish_command)
      end
    end

    desc "Accept the current shell input line and switch output to scrolling"
    action :submit_and_scroll do
      submit_line << Command.session(output_session.id, :paging_to_scrolling)
    end

    desc "Interrupt scrolling, otherwise quit Fatty"
    action :interrupt do
      if output_session.pager_active?
        Command.session(output_session.id, :quit_paging)
      else
        Command.terminal(:quit)
      end
    end

    desc "Quit if input is empty, otherwise delete forward"
    action :interrupt_if_empty do
      if output_session.pager_active?
        Command.session(output_session.id, :quit_paging)
      elsif @field.empty?
        Command.terminal(:quit)
      else
        @field.act_on(:delete_char_forward, env: action_env(event: nil))
        []
      end
    end

    desc "Clear shell output"
    action :clear_output do
      Command.session(output_session.id, :clear)
    end

    desc "Complete the current input prefix"
    action :complete do
      with_virtual_suffix_sync do
        @field.cycle_completion!
        []
      end
    end

    desc "Complete the previous input prefix"
    action :complete_previous do
      with_virtual_suffix_sync do
        @field.cycle_completion!(direction: -1)
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
          popup = PopUpSession.new(
            source: candidates,
            kind: :completion,
            title: "Completions",
            prompt: "Complete: ",
            order: :as_given,
            current: :top,
            initial_query: @field.popup_completion_query.to_s,
          )
          [[:terminal, :push_modal, popup]]
          Command.terminal(:push_modal, session: popup)
        end
      end
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
          current: :bottom,
          initial_query: @field.buffer.text,
          history: @history,
          history_kind: :popup_filter,
          history_ctx: {
            kind: :popup_filter,
            popup: :history_search,
            prompt: "I-search: ",
          },
        )
      Command.terminal(:push_modal, session: hist_searcher)
    end

    #########################################################################################
    # Other public API methods
    #########################################################################################

    # Save any state we want saved on quit, error, etc.
    def persist!
      return unless @history.respond_to?(:save!)

      Fatty.debug("ShellSession#persist!: saving history", tag: :history)
      @history.save!
    rescue => e
      Fatty.error("ShellSession#persist!: failed to save history: #{e.class}: #{e.message}", tag: :history)
    end

    # Called by Terminal#go on every loop iteration.  Returns true if any
    # visible state changed (dirty).
    def tick
      output_session.tick
    end

    def pager_active?
      output_session.pager_active?
    end

    def cursor_visible?
      !input_suppressed?
    end

    private

    # simplecov:disable

    def input_suppressed?
      terminal.modal_active? || output_session.pager_active?
    end

    def keymap_contexts
      [:input, :text, :terminal]
    end

    def apply_action(action, args, event:)
      which =
        if event&.respond_to?(:key)
          event.key.inspect
        elsif event&.respond_to?(:mouse)
          event.mouse.inspect
        end
      Fatty.debug("ShellSession#apply_action: #{which}", tag: :keymap)
      @field.reset_completion_state! unless action.to_sym == :complete
      env = action_env(event: event)
      defn = Fatty::Actions.lookup(action)
      result = Fatty::Actions.call(action, env, *args)

      @field.sync_virtual_suffix! if defn && [:field, :buffer].include?(defn[:on])
      normalize_action_result(result)
    rescue Fatty::ActionError => e
      [alert_cmd(:error, e.message, ev: event)]
    end

    def apply_popup_result(payload)
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

    #########################################################################################
    # Utilities
    #########################################################################################

    def pager
      output_session.pager
    end

    def accept_env
      CallbackEnvironment.new(terminal: terminal, output_id: output_session.id)
    end

    def run_default_command(line)
      commands = [Command.session(output_session.id, :append, text: "$ #{line}\n", follow: true)]
      out, status = Open3.capture2e(line)
      if status&.exitstatus && status.exitstatus != 0
        out << "\n[exit #{status.exitstatus}]\n"
      end
      commands << Command.session(output_session.id, :append, text: out, follow: true)
    rescue Errno::ENOENT => ex
      commands << Command.session(output_session.id, :append, text: ex.to_s, follow: true)
    end

    def unrecognized_key_alert(ev)
      if ev.uncoded?
        alert_cmd(
          :error,
          "Undefined key: #{ev.key} " \
          "(edit config in 'keydefs.yml' to name)",
          ev: ev,
        )
      else
        alert_cmd(
          :warn,
          "Unbound key: #{ev} " \
          "(edit config in 'keybindings.yml' to bind)",
          ev: ev,
        )
      end
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

    def with_virtual_suffix_sync
      @field.sync_virtual_suffix!
      result = yield
      @field.sync_virtual_suffix!
      result
    end
  end
end
