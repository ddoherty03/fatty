# frozen_string_literal: true

module Fatty
  class OutputSession < Session
    action_on :session

    attr_reader :output, :viewport, :pager, :pager_field

    def initialize(id: nil, keymap: nil, views: [])
      super(keymap: keymap)
      @output   = Fatty::OutputBuffer.new(max_lines: 500_000)
      @viewport = Fatty::Viewport.new(height: 10)
      mode = Fatty::Config.config.dig(:output, :mode)&.to_sym || :paging
      @default_output_mode = mode
      @pager = Fatty::Pager.new(output: @output, viewport: @viewport, mode: mode)
      @pager_field = Fatty::InputField.new(prompt: -> { pager_status_prompt })
    end

    def init(terminal:)
      super
    end

    def update(command)
      log_update(command)
      payload = command.payload
      commands =
        case command.action
        when :key
          ev = payload.fetch(:event)
          action, args = resolve_action(ev)
          if action
            apply_action(action, args, event: ev)
          else
            []
          end
        when :append
          case payload[:mode]
          when :scrolling
            pager.paging_to_scrolling
          when :paging
            pager.scrolling_to_paging
          end
          before = output.lines.length
          append_output(
            payload.fetch(:text, ""),
            follow: payload.fetch(:follow, true),
          )
          reveal_appended_block(before) if payload[:scroll]
          []
        when :clear
          reset_output!
          []
        when :resize
          resize_output!
          []
        when :begin_command
          reset_for_command!
          pager.begin_command!(anchor: output.lines.length)
          []
        when :quit_paging
          pager.quit
          []
        when :pager_search_set
          update_pager_search_set(payload)
        when :pager_search_step
          update_pager_search_step(payload)
        when :pager_isearch_update
          update_pager_isearch_update(payload)
        when :pager_isearch_step
          update_pager_isearch_step(payload)
        when :pager_isearch_cancel
          pager.isearch_cancel!
          [Command.session(:isearch, :isearch_set_failed, failed: false)]
        when :pager_isearch_commit
          update_pager_isearch_commit(payload)
        else
          []
        end
      Array(commands)
    end

    def view
      if pager_active?
        ::Curses.curs_set(0)

        viewport = pager_status_viewport(renderer.screen)
        renderer.render_output(output, viewport: viewport, highlights: highlights)
        renderer.render_pager_field(
          pager_field,
          row: renderer.screen.output_rect.rows - 1,
          role: :pager_status,
        )
      else
        renderer.render_output(output, viewport: pager_viewport, highlights: nil)
      end
    end

    def view
      if pager_active?
        ::Curses.curs_set(0)

        viewport = pager_status_viewport(renderer.screen)
        renderer.render_output(self)
        renderer.render_pager_field(
          pager_field,
          row: renderer.screen.output_rect.rows - 1,
          role: :pager_status,
        )
      else
        renderer.render_output(self)
      end
    end

    def tick
      dirty = false
      if pager.autoscroll?
        step = [(viewport.height * 3) / 4, 1].max
        dirty ||= pager.autoscroll_step?(max_lines: step)
      end
      dirty
    end

    def state
      [
        viewport.state,
        viewport.slice(output.lines),
        screen.output_rect.rows,
        renderer.screen.output_rect.cols,
        pager.search_visible_highlights(viewport: viewport),
        renderer.theme_version,
      ]
    end

    # True when the pager is currently holding the screen (i.e., paging mode is
    # active and the output is paused).
    def pager_active?
      @pager.active?
    end

    def highlights
      pager.search_visible_highlights(viewport: viewport)
    end

    private

    def keymap_contexts
      if pager.active?
        [:paging, :terminal]
      else
        [:terminal]
      end
    end

    def apply_action(action, args, event:)
      env = ActionEnvironment.new(
        session: self,
        event: event,
        counter: counter,
        pager: pager,
      )
      result = pager.act_on(action, *args, env: env)
      normalize_action_result(result)
    rescue Fatty::ActionError => e
      [alert_cmd(:error, e.message, ev: event)]
    end

    def reveal_appended_block(before)
      added = output.lines.length - before
      height = viewport.height.to_i

      if added >= height
        viewport.top = before
        viewport.clamp!(output.lines)
      else
        viewport.page_bottom(output.lines)
      end
    end

    desc "Search pager forward"
    action :pager_search_forward do
      regex = consume_search_regex_flag
      searcher = Fatty::SearchSession.new(direction: :forward, regex: regex, history: @history)
      Command.terminal(:push_modal, session: searcher, owner: self)
    end

    desc "Search pager backward"
    action :pager_search_backward do
      regex = consume_search_regex_flag
      searcher = Fatty::SearchSession.new(direction: :backward, regex: regex, history: @history)
      Command.terminal(:push_modal, session: searcher, owner: self)
    end

    desc "Start incremental pager search forward"
    action :pager_isearch_forward do
      isearcher = Fatty::ISearchSession.new(direction: :forward, history: @history, last_pattern: pager.search_pattern)
      Command.terminal(:push_modal, session: isearcher, owner: self)
    end

    desc "Start incremental pager search backward"
    action :pager_isearch_backward do
      isearcher = Fatty::ISearchSession.new(direction: :backward, history: @history, last_pattern: pager.search_pattern)
      Command.terminal(:push_modal, session: isearcher, owner: self)
    end

    desc "Repeat pager search forward"
    action :pager_search_next do
      handle_search_result(pager.search_repeat_next!)
    end

    desc "Repeat pager search backward"
    action :pager_search_prev do
      handle_search_result(pager.search_repeat_prev!)
    end

    def pager_status_viewport(screen)
      vp = pager_viewport.dup
      vp.height = [screen.output_rect.rows - 1, 1].max
      vp
    end

    def append_output(text, follow: true)
      ntrim = @output.append(text.to_s)
      @pager.on_append(ntrim: ntrim)

      # When callers request follow behavior (scrolling mode),
      # keep the viewport at the bottom unless paging is actively paused.
      if follow && !@pager.paused?
        case @pager.mode
        when :scrolling
          @viewport.page_bottom(@output.lines)
        end
      end
      ntrim
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

    def consume_search_regex_flag
      regex = false
      if counter.digits.to_s == "4"
        regex = true
        counter.clear!
      end
      regex
    end

    def reset_output!
      @output.lines.clear
      @viewport.reset
    end

    def resize_output!
      was_at_bottom = pager.at_bottom?
      @viewport.height = terminal.screen.output_rect.rows
      pager.preserve_after_resize!(was_at_bottom: was_at_bottom)
    end

    def reset_for_command!
      reset_output!
      mode = @default_output_mode # Fatty::Config.config.dig(:output, :mode)&.to_sym || :paging
      @pager.reset!(mode: mode)
    end

    # When the pager is active, the last output row is reserved for the pager
    # InputField. This returns the viewport to use for rendering the output
    # content itself.
    def pager_viewport
      if pager_active? && @viewport.height > 1
        Fatty::Viewport.new(top: @viewport.top, height: @viewport.height - 1)
      else
        @viewport
      end
    end

    def pager_status_prompt
      total = @output.lines.length
      visible_h = pager_active? ? pager.page_height : @viewport.height
      bottom = [@viewport.top + visible_h, total].min
      pct =
        if total.positive?
          ((bottom * 100.0) / total).round
        end

      search = pager.search_label
      search = "  [#{search}]" if search && !search.empty?
      if pct
        "  #{pager.nav_arrow} --More--  #{bottom}/#{total} (#{pct}%)#{search} "
      else
        "  #{pager.nav_arrow} --More--  #{bottom}#{search} "
      end
    end

    def reset_pager!
      # Start the next command from the bottom of existing scrollback.
      @viewport.page_bottom(@output.lines)
      @pager.reset!(total_lines: @output.lines.length, mode: @default_output_mode)
    end

    def follow_output!
      pager.end_of_output
      []
    end

    def page_output_from_top!
      pager.page_top
      []
    end

    def page_output_from_bottom!
      pager.page_bottom
      []
    end
  end
end
