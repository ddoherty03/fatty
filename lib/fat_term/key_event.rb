# frozen_string_literal: true
#

module FatTerm
  class KeyEvent
    attr_reader :key, :text, :ctrl, :meta, :shift, :raw

    def initialize(key:, text: nil, raw: nil, ctrl: false, meta: false, shift: false)
      @key  = key          # Symbol or named key
      @text = text         # String to insert (or nil)
      @raw = raw           # the key (or keys for escape sequences) as returned by Curses
      @ctrl = ctrl
      @meta = meta
      @shift = shift
    end

    def decoded?
      key.is_a?(Symbol)
    end

    def ctrl?
      @ctrl
    end

    def meta?
      @meta
    end

    def shift?
      @shift
    end
  end
end
