# frozen_string_literal: true
#

module FatTerm
  class KeyEvent
    attr_reader :key, :text, :ctrl, :meta, :shift

    def initialize(key:, text: nil, ctrl: false, meta: false, shift: false)
      @key  = key          # Symbol or named key
      @text = text         # String to insert (or nil)
      @ctrl = ctrl
      @meta = meta
      @shift = shift
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
