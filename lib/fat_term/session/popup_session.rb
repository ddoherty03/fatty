# frozen_string_literal: true

module FatTerm
  class PopUpSession < Session
    attr_reader :win, :field, :filtered, :selected, :title

    POPUP_MAX_WIDTH      = 80
    POPUP_DEFAULT_HEIGHT = 12
    POPUP_MIN_LIST_H     = 3
    POPUP_MAX_LIST_H     = 20
    POPUP_MARGIN         = 2

    def initialize(source:, title: nil, prompt: "> ", keymap: Keymaps.emacs)
      super(keymap: keymap)
      @source = source
      @title = title
      @field = InputField.new(prompt: prompt)

      @items = []
      @filtered = []
      @selected = 0

      @last_query = nil

      # Frozen popup geometry (computed once on init, based on initial
      # candidate count).
      @popup_width = nil
      @popup_height = nil
      @popup_list_h = nil
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
        end
        []
      when :popup_prev
        unless @filtered.empty?
          @selected = [@selected - 1, 0].max
        end
        []
      else
        # fallthrough: normal input editing actions
        @field.act_on(action, *args, env: env)
        refresh_items_if_query_changed
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
      @items = Array(@source.call(q))
      @filtered =
        if q.empty?
          @items
        else
          @items.select { |e| e.to_s.include?(q) }
        end
      @selected = @selected.clamp(0, [@filtered.length - 1, 0].max)
    end

    def view(screen:, renderer:, terminal:)
      renderer.render_popup(session: self)
    end

    private

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
        event: event,
        field: @field,
        buffer: @field.buffer,
      )
    end
  end
end
