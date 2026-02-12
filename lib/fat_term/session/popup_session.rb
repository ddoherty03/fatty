module FatTerm
  class PopUpSession < Session
    attr_reader :win

    def initialize(source:, title: nil, prompt: "> ")
      @source = source
      @title = title
      @field = InputField.new(prompt: prompt)

      @items = []
      @filtered = []
      @selected = 0

      @keymap = Keymaps.emacs
      @last_query = nil
    end

    def init(terminal:)
      rebuild_windows!(terminal)
      refresh_items
      []
    end

    def handle_resize(terminal)
      rebuild_windows!(terminal)
      []
    end

    def rebuild_windows!(terminal)
      @win&.close rescue nil
      cols = ::Curses.cols
      rows = ::Curses.lines
      width  = [cols - 4, 80].min
      height = [rows - 4, 12].min
      x = (cols - width) / 2
      y = (rows - height) / 2
      @win = ::Curses::Window.new(height, width, y, x)
    end

    def update(message, terminal:)
      case message[0]
      when :key
        update_key(message[1], terminal: terminal)
      when :cmd
        []
      else
        []
      end
    end

    def resolve_action(ev)
      @keymap.resolve_action(ev, contexts: [:popup, :input])
    end

    def update_key(ev, terminal:)
      return handle_resize(terminal) if ev.key == :resize

      action, *args = Array(resolve_action(ev))
      return [] unless action

      apply_action(action, args, ev, terminal: terminal)
    end

    def apply_action(action, args, ev, terminal:)
      case action
      when :popup_cancel
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
        @field.act_on(action, *args)
        refresh_items_if_query_changed
        []
      end
    end

    def accept_selection
      item = @filtered[@selected]
      return [] unless item

      payload = { item: item, query: @field.buffer.text.to_s, index: @selected }
      [
        [:terminal, :pop_modal],
        [:terminal, :send_modal_owner, [:cmd, :popup_result, payload]]
      ]
    end

    def refresh_items_if_query_changed
      q = @field.buffer.text.to_s
      return if q == @last_query

      @last_query = q
      refresh_items
    end

    def refresh_items
      q = @field.buffer.text.to_s
      @items = Array(@source.call(q))
      @filtered = @items # source already filtered; later you can support “source.all + local filter”
      @selected = @selected.clamp(0, [@filtered.length - 1, 0].max)
    end

    def view(screen:, renderer:, terminal:)
      renderer.render_popup(session: self)
    end

    attr_reader :field, :filtered, :selected, :title
  end
end
