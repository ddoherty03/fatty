# frozen_string_literal: true

module FatTerm
  class PopUpSession < Session
    attr_reader :win, :field, :filtered, :selected, :title

    POPUP_MAX_WIDTH      = 80
    POPUP_DEFAULT_HEIGHT = 12
    POPUP_MIN_LIST_H     = 3
    POPUP_MAX_LIST_H     = 20
    POPUP_MARGIN         = 2

    # API:
    # - source: Proc that returns the candidate list. May accept (query) or be arity 0.
    # - matcher: Proc (item, query) -> truthy. Defaults to substring match.
    # - order: :as_given (default) or :reverse (presentation order).
    # - selection: :preserve (default), :top, :bottom (how selection behaves after refresh).
    def initialize(
      source:,
      title: nil,
      prompt: "> ",
      keymap: Keymaps.emacs,
      matcher: nil,
      order: :as_given,
      selection: :preserve
    )
      super(keymap: keymap)
      @source = source
      @matcher = matcher
      @order = order.to_sym
      @selection = selection.to_sym

      @title = title
      @prompt = Prompt.ensure(prompt)
      @field = InputField.new(prompt: @prompt)

      @items = []
      @filtered = []
      @selected = 0

      @last_query = nil

      # Frozen popup geometry (computed once on init, based on initial
      # candidate count).
      @popup_width = nil
      @popup_height = nil
      @popup_list_h = nil
      @scroll_start = 0
    end

    def keymap_contexts
      [:popup, :input]
    end

    def init(terminal:)
      refresh_items
      capture_initial_popup_geometry!
      rebuild_windows!(terminal)
      []
    end

    def update_key(ev, terminal:)
      return handle_resize(terminal) if ev.key == :resize

      []
    end

    def rebuild_windows!(terminal)
      @win&.close rescue nil
      cols = ::Curses.cols
      rows = ::Curses.lines
      width, height = popup_geometry(cols: cols, rows: rows)
      x = (cols - width) / 2
      y = (rows - height) / 2
      @win = ::Curses::Window.new(height, width, y, x)
    end

    def popup_geometry(cols:, rows:)
      width = @popup_width || POPUP_MAX_WIDTH
      height = @popup_height || POPUP_DEFAULT_HEIGHT

      max_w = cols - (POPUP_MARGIN * 2)
      max_h = rows - (POPUP_MARGIN * 2)

      width = max_w if width > max_w
      height = max_h if height > max_h

      width = 10 if width < 10
      height = 5 if height < 5

      [width, height]
    end

    def handle_action(action, args, terminal:, event:)
      env = action_env(terminal: terminal, event: event)
      case action.to_sym
      when :popup_cancel, :interrupt
        [[:terminal, :pop_modal]]
      when :popup_accept
        accept_selection
      when :popup_next
        unless @filtered.empty?
          @selected = [@selected + 1, @filtered.length - 1].min
          ensure_scroll_visible
        end
        []
      when :popup_prev
        unless @filtered.empty?
          @selected = [@selected - 1, 0].max
          ensure_scroll_visible
        end
        []
      when :popup_page_down
        move_selected_by(popup_list_height)
        ensure_scroll_visible
        []
      when :popup_page_up
        move_selected_by(-popup_list_height)
        ensure_scroll_visible
        []
      when :popup_top
        unless @filtered.empty?
          @selected = 0
          recenter_scroll
        end
        []
      when :popup_bottom
        unless @filtered.empty?
          @selected = [@filtered.length - 1, 0].max
          recenter_scroll
        end
        []
      when :popup_recenter
        recenter_scroll
        []
      else
        # fallthrough: normal input editing actions
        @field.act_on(action, *args, env: env)
        refresh_items_if_query_changed
        ensure_scroll_visible
        []
      end
    rescue ActionError => e
      FatTerm.log("PopUpSession.handle_action: ActionError #{e.message}", tag: :keymap)
      []
    end

    def accept_selection
      item = @filtered[@selected]
      return [] unless item

      payload = { item: item, query: @field.buffer.text.to_s, index: @selected }
      [
        [:terminal, :send_modal_owner, [:cmd, :popup_result, payload]],
        [:terminal, :pop_modal]
      ]
    end

    def refresh_items_if_query_changed
      q = @field.buffer.text.to_s
      return if q == @last_query

      @last_query = q.dup.freeze
      FatTerm.debug("popup query changed", tag: :popup, q: q, last: @last_query)
      refresh_items
    end

    def refresh_items
      q = @field.buffer.text.to_s
      @items = Array(call_source(q))
      apply_order!
      matcher = @matcher || method(:default_matcher)
      @filtered =
        if q.empty?
          @items
        else
          @items.select { |e| matcher.call(e, q) }
        end
      apply_selection_policy!
    end

    def view(screen:, renderer:, terminal:)
      renderer.render_popup(session: self)
    end

    # Renderer calls this to determine which slice of items to display.
    def scroll_start(list_h:)
      max_start = @filtered.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
      @scroll_start
    end

    private

    def popup_list_height
      # Visible list lines = window height minus:
      # - 2 border rows
      # - 1 input row
      #
      # If window isn't built yet, fall back to the historical default (12 high).
      if @win
        h = @win.maxy
      else
        h = 12
      end

      list_h = h - 3
      list_h = 1 if list_h < 1
      list_h
    end

    def move_selected_by(delta)
      return if @filtered.empty?

      @selected = (@selected + delta).clamp(0, @filtered.length - 1)
    end

    def ensure_scroll_visible
      list_h = popup_list_height

      # dead-zone is top/bottom 10% of visible list, at least 1 line
      band = (list_h * 0.10).floor
      band = 1 if band < 1

      top_zone = @scroll_start + band
      bot_zone = (@scroll_start + list_h - 1) - band

      if @selected < top_zone
        @scroll_start = @selected - band
      elsif @selected > bot_zone
        @scroll_start = @selected - (list_h - 1) + band
      end

      max_start = @filtered.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
    end

    def recenter_scroll
      list_h = popup_list_height
      @scroll_start = @selected - (list_h / 2)

      max_start = @filtered.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
    end

    def call_source(q)
      if @source.arity == 0
        @source.call
      else
        @source.call(q)
      end
    end

    def apply_order!
      case @order
      when :as_given
        # no-op
      when :reverse
        @items = @items.reverse
      else
        # unknown order; ignore
      end
    end

    def apply_selection_policy!
      last_idx = [@filtered.length - 1, 0].max

      if @filtered.empty?
        @selected = 0
      else
        prior = @selected
        @selected =
          case @selection
          when :top
            0
          when :bottom
            last_idx
          else
            @selected.clamp(0, last_idx)
          end
      end
      # If the selection policy explicitly moved the cursor, keep it in view.
      if @selection == :top || @selection == :bottom
        recenter_scroll
      elsif @selected != prior
        ensure_scroll_visible
      end
    end

    def default_matcher(item, query)
      q = query.to_s.strip
      return true if q.empty?

      # Split query on whitespace
      terms = q.split(/\s+/).reject(&:empty?)
      return true if terms.empty?

      hay = item.to_s.downcase
      terms.all? { |t| hay.include?(t.downcase) }
    end

    def capture_initial_popup_geometry!
      return if @popup_height && @popup_width

      count = @filtered.length
      list_h = count
      list_h = POPUP_MIN_LIST_H if list_h < POPUP_MIN_LIST_H
      list_h = POPUP_MAX_LIST_H if list_h > POPUP_MAX_LIST_H

      @popup_list_h = list_h
      @popup_height = @popup_list_h + 3
      @popup_width = POPUP_MAX_WIDTH
    end

    def handle_resize(terminal)
      rebuild_windows!(terminal)
      []
    end

    def action_env(terminal:, event:)
      ActionEnvironment.new(
        session: self,
        terminal: terminal,
        counter: counter,
        event: event,
        field: @field,
        buffer: @field.buffer,
      )
    end
  end
end
