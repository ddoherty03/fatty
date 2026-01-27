# frozen_string_literal: true

module FatTerm
  # The KeyEvent class is a simple class to store a key with its modifiers.
  # KeyMap will map a KeyEvent to an action (for a given context), and the
  # KeyDecoder class is responsible for turning raw key inputs from curses
  # into a KeyEvent.  The CURSES_TO_EVENT constant is an initial map from
  # known curses key codes to KeyEvents.  These can be overriden for different
  # terminals in FatTerm::Config.keydefs.
  class KeyEvent
    attr_reader :key, :text, :ctrl, :meta, :shift, :raw

    def initialize(key:, text: nil, raw: nil, ctrl: false, meta: false, shift: false)
      @key = key           # Symbol or named key
      @raw = raw           # the key (or keys for escape sequences) as returned by Curses
      @ctrl = ctrl
      @meta = meta
      @shift = shift
      # invariant: chorded keys do not self-insert
      @text = ctrl || meta ? nil : text
    end

    def ==(other)
      other.is_a?(KeyEvent) &&
        key == other.key &&
        ctrl == other.ctrl &&
        meta == other.meta &&
        shift == other.shift
    end
    alias_method :eql?, :==

    def hash
      [key, ctrl, meta, shift].hash
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
