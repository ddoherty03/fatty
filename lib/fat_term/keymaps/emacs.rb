# frozen_string_literal: true

module FatTerm
  module Keymaps
    def self.emacs
      map = KeyMap.new

      # Motion
      map.bind(key: :f, ctrl: true, action: :forward_char)
      map.bind(key: :b, ctrl: true, action: :backward_char)
      map.bind(key: :left,  action: :backward_char)
      map.bind(key: :right, action: :forward_char)
      map.bind(key: :f, meta: true, action: :forward_word)
      map.bind(key: :b, meta: true, action: :backward_word)
      map.bind(key: :right, meta: true, action: :forward_word)
      map.bind(key: :left, meta: true, action: :backward_word)
      map.bind(key: :right, ctrl: true, action: :forward_word)
      map.bind(key: :left, ctrl: true, action: :backward_word)

      map.bind(key: :a, ctrl: true, action: :bol)
      map.bind(key: :e, ctrl: true, action: :eol)
      map.bind(key: :home, action: :bol)
      map.bind(key: :end, action: :eol)

      # Deletion
      map.bind(key: :delete, action: :delete_char_forward)
      map.bind(key: :d, ctrl: true, action: :delete_char_forward)
      map.bind(key: :backspace, action: :delete_char_backward)
      map.bind(key: :backspace, ctrl: true, action: :delete_word_backward)
      map.bind(key: :w, ctrl: true, action: :delete_word_backward)
      map.bind(key: :d, meta: true, action: :delete_word_forward)
      map.bind(key: :k, ctrl: true, action: :kill_to_eol)

      # History
      map.bind(key: :p, ctrl: true, action: :history_prev)
      map.bind(key: :n, ctrl: true, action: :history_next)
      map.bind(key: :up, action: :history_prev)
      map.bind(key: :down, action: :history_next)

      # Final States
      map.bind(key: :c, ctrl: true, action: :interrupt)
      map.bind(key: :d, ctrl: true, action: :interrupt_if_empty)
      map.bind(key: :enter, action: :accept_line)
      map.bind(key: :j, ctrl: true, action: :accept_line)

      map.load_config
    end
  end
end
