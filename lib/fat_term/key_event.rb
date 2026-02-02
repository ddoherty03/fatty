# frozen_string_literal: true

module FatTerm
  # The KeyEvent class is a simple class to store a key with its modifiers.
  # KeyMap will map a KeyEvent to an action (for a given context), and the
  # KeyDecoder class is responsible for turning raw key inputs from curses
  # into a KeyEvent.  The CURSES_TO_EVENT constant is an initial map from
  # known curses key codes to KeyEvents.  These can be overriden for different
  # terminals in FatTerm::Config.keydefs.
  class KeyEvent
    CTRL_CODE_TO_LETTER = (1..26).each_with_object({}) do |n, h|
      # 1->:a, 2->:b, ... 21->:u, 23->:w
      h[n] = (96 + n).chr.to_sym
    end.freeze

    CTRL_PUNCT = {
      27 => :"[",   # ESC is also C-[
      28 => :"\\",  # C-\
      29 => :"]",   # C-]
      30 => :"^",   # C-^
      31 => :"_",   # C-_
    }.freeze

    private_constant :CTRL_CODE_TO_LETTER

    attr_reader :key, :text, :ctrl, :meta, :shift, :raw

    def initialize(key:, text: nil, raw: nil, ctrl: false, meta: false, shift: false)
      # If the decoder gives us a control character as an integer (1..26),
      # canonicalize it to ctrl+letter so keymaps and display behave nicely.
      if key.is_a?(Integer)
        if CTRL_CODE_TO_LETTER.key?(key)
          key = CTRL_CODE_TO_LETTER[key]
          ctrl = true
        elsif CTRL_PUNCT.key?(key)
          key = CTRL_PUNCT[key]
          ctrl = true
        end
      end
      @key = key           # Symbol or named key
      @raw = raw           # the key (or keys for escape sequences) as returned by Curses
      @ctrl = ctrl
      @meta = meta
      @shift = shift
      # invariant: chorded keys do not self-insert
      @text = ctrl || meta ? nil : text
    end

    def to_s
      mods = []
      mods << "C" if ctrl?
      mods << "M" if meta?
      mods << "S" if shift?

      key_str = key ? key.to_s : "<?>"

      mods.empty? ? key_str : "#{mods.join('-')}-#{key_str}"
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
