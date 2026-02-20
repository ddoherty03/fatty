# frozen_string_literal: true

module FatTerm
  module Keymaps
    def self.emacs
      map = KeyMap.new

      # Motion
      map.bind(key: :f, ctrl: true, action: :move_right)
      map.bind(key: :b, ctrl: true, action: :move_left)
      map.bind(key: :right, action: :move_right)
      map.bind(key: :left,  action: :move_left)
      map.bind(key: :f, meta: true, action: :move_word_right)
      map.bind(key: :b, meta: true, action: :move_word_left)
      map.bind(key: :right, meta: true, action: :move_word_right)
      map.bind(key: :left, meta: true, action: :move_word_left)
      map.bind(key: :right, ctrl: true, action: :move_word_right)
      map.bind(key: :left, ctrl: true, action: :move_word_left)

      map.bind(key: :a, ctrl: true, action: :bol)
      map.bind(key: :e, ctrl: true, action: :eol)
      map.bind(key: :home, action: :bol)
      map.bind(key: :end, action: :eol)

      # Deletion
      map.bind(key: :delete, action: :delete_char_forward)
      map.bind(key: :d, ctrl: true, action: :delete_char_forward)
      map.bind(key: :backspace, action: :delete_char_backward)
      map.bind(key: :backspace, meta: true, action: :kill_word_backward)
      map.bind(key: :w, ctrl: true, action: :kill_word_backward)
      map.bind(key: :d, meta: true, action: :kill_word_forward)
      map.bind(key: :k, ctrl: true, action: :kill_to_eol)

      # Undo / Redo
      map.bind(key: :/, ctrl: true, action: :undo)
      map.bind(key: :_, ctrl: true, action: :undo)
      map.bind(key: :/, ctrl: true, meta: true, action: :redo)
      map.bind(key: :/, meta: true, action: :redo)

      # Region / Mark
      map.bind(key: :space, ctrl: true, action: :set_mark)
      map.bind(key: :'@', ctrl: true, action: :set_mark)
      map.bind(key: :g, ctrl: true, action: :clear_mark)
      map.bind(key: :w, ctrl: true, action: :kill_region)
      map.bind(key: :w, meta: true, action: :copy_region)

      # Yank / Kill ring
      map.bind(key: :y, ctrl: true, action: :yank)
      map.bind(key: :y, meta: true, action: :yank_pop)

      # Counts (prefix arg)
      map.bind(key: :u, ctrl: true, action: :universal_argument)
      map.bind(key: :'0', meta: true, action: [:meta_digit, 0])
      map.bind(key: :'1', meta: true, action: [:meta_digit, 1])
      map.bind(key: :'2', meta: true, action: [:meta_digit, 2])
      map.bind(key: :'3', meta: true, action: [:meta_digit, 3])
      map.bind(key: :'4', meta: true, action: [:meta_digit, 4])
      map.bind(key: :'5', meta: true, action: [:meta_digit, 5])
      map.bind(key: :'6', meta: true, action: [:meta_digit, 6])
      map.bind(key: :'7', meta: true, action: [:meta_digit, 7])
      map.bind(key: :'8', meta: true, action: [:meta_digit, 8])
      map.bind(key: :'9', meta: true, action: [:meta_digit, 9])

      # History
      map.bind(key: :p, ctrl: true, action: :history_prev)
      map.bind(key: :n, ctrl: true, action: :history_next)
      map.bind(key: :up, action: :history_prev)
      map.bind(key: :down, action: :history_next)
      map.bind(key: :r, ctrl: true, action: :history_search)

      # Popup
      map.bind(context: :popup, key: :c, ctrl: true, action: :popup_cancel)
      map.bind(context: :popup, key: :g, ctrl: true, action: :popup_cancel)
      map.bind(context: :popup, key: :escape, action: :popup_cancel)
      map.bind(context: :popup, key: :enter, action: :popup_accept)
      map.bind(context: :popup, key: :return, action: :popup_accept)
      map.bind(context: :popup, key: :up, action: :popup_prev)
      map.bind(context: :popup, key: :down, action: :popup_next)
      map.bind(context: :popup, key: :p, ctrl: true, action: :popup_prev)
      map.bind(context: :popup, key: :n, ctrl: true, action: :popup_next)
      map.bind(context: :popup, key: :page_up, action: :popup_page_up)
      map.bind(context: :popup, key: :page_down, action: :popup_page_down)
      map.bind(context: :popup, key: :v, meta: true, action: :popup_page_up)
      map.bind(context: :popup, key: :v, ctrl: true, action: :popup_page_down)
      map.bind(context: :popup, key: :home, action: :popup_top)
      map.bind(context: :popup, key: :g, action: :popup_top)
      map.bind(context: :popup, key: :end, action: :popup_bottom)
      map.bind(context: :popup, key: :G, action: :popup_bottom)
      map.bind(context: :popup, key: :'<', meta: true, action: :popup_top)
      map.bind(context: :popup, key: :'>', meta: true, action: :popup_bottom)
      map.bind(context: :popup, key: :l, ctrl: true, action: :popup_recenter)
      # map.bind(context: :popup, key: :g, action: :popup_top)
      # map.bind(context: :popup, key: :G, shift: true, action: :popup_bottom)

      # Themes
      map.bind(context: :terminal, key: :t, meta: true, ctrl: true, action: :cycle_theme)

      # Final States
      map.bind(key: :c, ctrl: true, action: :interrupt)
      map.bind(key: :d, ctrl: true, action: :interrupt_if_empty)
      map.bind(key: :enter, action: :accept_line)
      map.bind(key: :return, action: :accept_line)
      map.bind(key: :j, ctrl: true, action: :accept_line)

      # Output control
      map.bind(key: :l, ctrl: true, action: :clear_output)
      map.bind(context: :paging, key: :page_up, action: :page_up)
      map.bind(context: :paging, key: :b, action: :page_up)
      map.bind(context: :paging, key: :u, action: :page_up)
      map.bind(context: :paging, key: :h, ctrl: true, action: :page_up)
      map.bind(context: :paging, key: :page_down, action: :page_down)
      map.bind(context: :paging, key: :f, action: :page_down)
      map.bind(context: :paging, key: :d, action: :page_down)
      map.bind(context: :paging, key: :space, action: :page_down)
      map.bind(context: :paging, key: :v, ctrl: true, action: :page_down)
      map.bind(context: :paging, key: :v, meta: true, action: :page_up)
      map.bind(context: :paging, key: :home, action: :page_top)
      map.bind(context: :paging, key: :g, action: :page_top)
      map.bind(context: :paging, key: :'<', meta: true, action: :page_top)
      map.bind(context: :paging, key: :end, action: :page_bottom)
      map.bind(context: :paging, key: :G, action: :page_bottom)
      map.bind(context: :paging, key: :'>', meta: true, action: :page_bottom)
      map.bind(context: :paging, key: :s, meta: true, action: :paging_to_scrolling)
      map.bind(context: :paging, key: :c, ctrl: true, action: :quit_paging)
      map.bind(context: :paging, key: :d, ctrl: true, action: :quit_paging)
      map.bind(context: :paging, key: :q, action: :quit_paging)

      map.load_config
    end
  end
end
