module FatTerm
  class PopUpSession < Session
    attr_reader :win

    def initialize(source:, title: nil, prompt: "> ", keymap: Keymaps.emacs)
      super(keymap: keymap)
      @source = source
      @title = title
      @field = InputField.new(prompt: prompt)

      @items = []
      @filtered = []
      @selected = 0

      @last_query = nil

    def keymap_contexts
      [:popup, :input]
    end

    def init(terminal:)
      rebuild_windows!(terminal)
      refresh_items
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
      width  = [cols - 4, 80].min
      height = [rows - 4, 12].min
      x = (cols - width) / 2
      y = (rows - height) / 2
      @win = ::Curses::Window.new(height, width, y, x)
    end





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

    attr_reader :field, :filtered, :selected, :title
  end
end
