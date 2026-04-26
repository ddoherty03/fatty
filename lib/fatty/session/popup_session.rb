# frozen_string_literal: true

module Fatty
  class PopUpSession < ModalSession
    attr_reader :field, :filtered, :displayed, :selected, :title, :message

    MAX_WIDTH      = 120
    DEFAULT_HEIGHT = 12
    MIN_LIST_H     = 3
    MAX_LIST_H     = 20
    MARGIN         = 2

    SELECTED_GUTTER = '[X] '
    UNSELECTED_GUTTER = '[ ] '

    # API:
    # - source: Proc that returns the candidate list. May accept (query) or be arity 0.
    # - matcher: Proc (item, query) -> truthy. Defaults to substring match.
    # - order: :as_given (default) or :reverse (presentation order).
    # - selection: :preserve (default), :top, :bottom (how selection behaves after refresh).
    def initialize(
          source:,
          title: nil,
          message: nil,
          prompt: "> ",
          keymap: Keymaps.emacs,
          matcher: nil,
          order: :as_given,
          kind: nil,
          selection: :preserve,
          initial_query: nil,
          selection_mode: :single,
          validate_unique_labels: false
        )
      super(keymap: keymap)
      @source = source
      @title = title&.to_s
      @message = message&.to_s
      @prompt = Prompt.ensure(prompt)
      @matcher = matcher
      @order = order.to_sym
      @kind = kind&.to_sym
      @selection = selection.to_sym
      @selection_mode = selection_mode.to_sym
      @validate_unique_labels = !!validate_unique_labels

      @field = InputField.new(prompt: @prompt)
      text = initial_query.to_s
      @field.buffer.replace(text) unless text.empty?

      @items = []
      @filtered = []
      @displayed = []
      @selected = 0
      @selected_labels = {}

      @last_query = nil
      @scroll_start = 0
    end

    def keymap_contexts
      [:popup, :input]
    end

    def keymap_contexts
      contexts = [:popup, :input]
      contexts.unshift(:popup_multi) if multi_select?
      contexts
    end

    def init(terminal:)
      refresh_items
      rebuild_windows!
      notify_owner(:popup_changed)
    end

    # Return the outer width and height of the window for this modal,
    # including any padding and borders.
    def geometry(cols:, rows:)
      max_w = max_width(cols: cols, margin: MARGIN, min_width: 10)
      max_h = max_height(rows: rows, margin: MARGIN, min_height: 5)

      desired_list_h = @filtered.length.clamp(MIN_LIST_H, MAX_LIST_H)
      height = clamp_height(
        desired_list_h + popup_extra_rows,
        max_height: max_h,
        min_height: 6,
      )
      width = clamp_width(
        MAX_WIDTH,
        max_width: max_w,
      )
      [width, height]
    end

    def handle_action(action, args, event:)
      env = action_env(event: event)
      case action.to_sym
      when :popup_cancel, :interrupt
        notify_owner(:popup_cancelled) + [[:terminal, :pop_modal]]
      when :popup_accept
        accept_selection
      when :popup_next
        move_selected_by(1)
        ensure_scroll_visible
        notify_owner(:popup_changed)
      when :popup_prev
        move_selected_by(-1)
        ensure_scroll_visible
        notify_owner(:popup_changed)
      when :popup_page_down
        move_selected_by(popup_list_height)
        ensure_scroll_visible
        notify_owner(:popup_changed)
      when :popup_page_up
        move_selected_by(-popup_list_height)
        ensure_scroll_visible
        notify_owner(:popup_changed)
      when :popup_top
        unless @filtered.empty?
          @selected = 0
          recenter_scroll
        end
        notify_owner(:popup_changed)
      when :popup_bottom
        unless @filtered.empty?
          @selected = [@filtered.length - 1, 0].max
          recenter_scroll
        end
        notify_owner(:popup_changed)
      when :popup_recenter
        recenter_scroll
        []
      when :popup_toggle_selected
        if multi_select?
          toggle_selected_current!
          ensure_scroll_visible
          notify_owner(:popup_changed)
        else
          []
        end
      else
        # fallthrough: normal input editing actions
        @field.act_on(action, *args, env: env)
        refresh_items_if_query_changed
        ensure_scroll_visible
        notify_owner(:popup_changed)
      end
    rescue ActionError => e
      Fatty.error("PopUpSession#handle_action: ActionError #{e.message}", tag: :session)
      []
    end

    def move_selected_by(delta)
      return if @displayed.empty?

      msg = "PopUpSession#move_selected_by before: selected=#{@selected.inspect} delta=#{delta} len=#{@displayed.length}"
      Fatty.debug(msg)
      @selected = ((@selected || 0) + delta) % @displayed.length
      Fatty.debug("PopUpSession#move_selected_by after: selected=#{@selected.inspect}")
    end

    def accept_selection
      if multi_select?
        payload = popup_payload(selected_result_hash)
        [
          [:terminal, :send_modal_owner, [:cmd, :popup_result, payload]],
          [:terminal, :pop_modal]
        ]
      else
        item = selected_item
        query = @field.buffer.text.to_s

        return [] if item.nil? && query.empty?

        item = query if item.nil?
        payload = popup_payload(item)
        [
          [:terminal, :send_modal_owner, [:cmd, :popup_result, payload]],
          [:terminal, :pop_modal]
        ]
      end
    end

    def selected_item
      @displayed[@selected]
    end

    def selected_item_label?(item)
      selected_label?(item_label(item))
    end

    def gutter_for(item:, selected:)
      if multi_select?
        selected_item_label?(item) ? SELECTED_GUTTER : UNSELECTED_GUTTER
      else
        ' '
      end
    end

    def refresh_items_if_query_changed
      q = @field.buffer.text.to_s
      return if q == @last_query

      @last_query = q.dup.freeze
      Fatty.debug("popup query changed", tag: :popup, q: q, last: @last_query)
      refresh_items
    end

    def refresh_displayed_items
      if multi_select?
        selected_missing =
          @items.select do |item|
          label = item_label(item)
          selected_label?(label) && !@filtered.include?(item)
        end

        @displayed = selected_missing + @filtered
      else
        @displayed = @filtered.dup
      end
    end

    def refresh_items
      q = @field.buffer.text.to_s
      @items = Array(call_source(q))
      apply_order!
      validate_unique_labels!(@items) if @validate_unique_labels

      matcher = @matcher || method(:default_matcher)

      @filtered =
        if q.empty?
          @items
        else
          @items.select { |e| matcher.call(e, q) }
        end

      refresh_displayed_items
      apply_selection_policy!
    end

    def view(screen:, renderer:)
      Fatty.debug("PopupSession#view: object_id=#{object_id} win_nil=#{@win.nil?}", tag: :session)
      return unless @win

      renderer.render_popup(session: self)
    end

    # Renderer calls this to determine which slice of items to display.
    def scroll_start(list_h:)
      max_start = @displayed.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
      @scroll_start
    end

    def toggle_selected_current!
      item = selected_item
      return unless item

      toggle_selected_item!(item)
    end

    def toggle_selected_item!(item)
      label = item_label(item)

      if selected_label?(label)
        @selected_labels.delete(label)
      else
        @selected_labels[label] = true
      end

      refresh_displayed_items
      item
    end

    # Count methods for display to user.

    def total_count
      @items.length
    end

    def matching_count
      @filtered.length
    end

    def selected_count
      if multi_select?
        @selected_labels.length
      else
        selected_item ? 1 : 0
      end
    end

    def showing_count
      [@displayed.length - scroll_start(list_h: popup_list_height), popup_list_height].min
    end

    def counts
      {
        total: total_count,
        selected: selected_count,
        matching: matching_count,
        showing: showing_count
      }
    end

    def selected_labels
      @selected_labels.keys
    end

    private

    def validate_unique_labels!(items)
      counts = Hash.new(0)
      items.each do |item|
        counts[item_label(item)] += 1
      end

      dupes = counts.select { |_label, count| count > 1 }.keys
      return if dupes.empty?

      shown = dupes.first(5).join(", ")
      raise ArgumentError, "duplicate chooser labels: #{shown}"
    end

    def popup_payload(item = selected_item)
      {
        kind: @kind,
        item: item,
        query: @field.buffer.text.to_s,
        index: @selected
      }
    end

    def popup_payload(item = selected_item)
      if multi_select?
        {
          kind: @kind,
          items: item,
          query: @field.buffer.text.to_s,
          index: @selected
        }
      else
        {
          kind: @kind,
          item: item,
          query: @field.buffer.text.to_s,
          index: @selected
        }
      end
    end

    def popup_has_message?
      @message && !@message.empty?
    end

    def popup_extra_rows
      rows = 4
      rows += 1 if popup_has_message?
      rows
    end

    def notify_owner(name)
      return [] unless @kind

      [[:terminal, :send_modal_owner, [:cmd, name, popup_payload]]]
    end

    def popup_list_height
      # Visible list lines = window height minus:
      # - 2 border rows
      # - 1 input row
      # - 1 message row when present
      #
      # If window isn't built yet, fall back to the historical default.
      h =
        begin
          @win ? @win.maxy : DEFAULT_HEIGHT
        rescue RuntimeError
          DEFAULT_HEIGHT
        end

      list_h = h - popup_extra_rows
      list_h = 1 if list_h < 1
      list_h
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

      max_start = @displayed.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
    end

    def recenter_scroll
      list_h = popup_list_height
      @scroll_start = @selected - (list_h / 2)

      max_start = @displayed.length - list_h
      max_start = 0 if max_start < 0

      @scroll_start = 0 if @scroll_start < 0
      @scroll_start = max_start if @scroll_start > max_start
    end

    def call_source(q)
      items =
        if @source.respond_to?(:call)
          if @source.arity == 0
            @source.call
          else
            @source.call(q)
          end
        else
          @source
        end
      Array(items)
    end

    def apply_order!
      case @order
      when :as_given
        # no-op
      when :reverse
        @items = @items.reverse
      end
    end

    def apply_selection_policy!
      prior = @selected
      last_idx = [@displayed.length - 1, 0].max

      if @displayed.empty?
        @selected = 0
      else
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

      if @selection == :top || @selection == :bottom
        recenter_scroll
      elsif @selected != prior
        ensure_scroll_visible
      end
    end

    def default_matcher(item, query)
      match_all_query_terms?(item, query)
    end

    def action_env(event:)
      ActionEnvironment.new(
        session: self,
        counter: counter,
        event: event,
        field: @field,
        buffer: @field.buffer,
      )
    end

    def multi_select?
      @selection_mode == :multiple
    end

    def item_label(item)
      item.to_s
    end

    def item_value(item)
      item
    end

    def selected_label?(label)
      @selected_labels.key?(label)
    end

    def selected_item?
      !selected_item.nil?
    end

    def selected_items_in_source_order
      @items.select { |item| selected_label?(item_label(item)) }
    end

    def selected_result_hash
      selected_items_in_source_order.each_with_object({}) do |item, h|
        h[item_label(item)] = item_value(item)
      end
    end
  end
end
