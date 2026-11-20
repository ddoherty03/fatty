# frozen_string_literal: true

module Fatty
  module Curses
    # Native modified-key codes from PDCursesMod curses.h and wincon/pdckbd.c.
    # Ruby curses omits most of these constants. Offsets work for both narrow
    # and Unicode builds; the decoder installs them only on PDCurses, before
    # user overrides. Do not infer extra modifiers the backend did not report.
    module PDCursesKeys
      OFFSETS = {
        0x97 => { key: :'0', meta: true }, # ALT_0
        0x98 => { key: :'1', meta: true }, # ALT_1
        0x99 => { key: :'2', meta: true }, # ALT_2
        0x9a => { key: :'3', meta: true }, # ALT_3
        0x9b => { key: :'4', meta: true }, # ALT_4
        0x9c => { key: :'5', meta: true }, # ALT_5
        0x9d => { key: :'6', meta: true }, # ALT_6
        0x9e => { key: :'7', meta: true }, # ALT_7
        0x9f => { key: :'8', meta: true }, # ALT_8
        0xa0 => { key: :'9', meta: true }, # ALT_9
        0xa1 => { key: :a, meta: true }, # ALT_A
        0xa2 => { key: :b, meta: true }, # ALT_B
        0xa3 => { key: :c, meta: true }, # ALT_C
        0xa4 => { key: :d, meta: true }, # ALT_D
        0xa5 => { key: :e, meta: true }, # ALT_E
        0xa6 => { key: :f, meta: true }, # ALT_F
        0xa7 => { key: :g, meta: true }, # ALT_G
        0xa8 => { key: :h, meta: true }, # ALT_H
        0xa9 => { key: :i, meta: true }, # ALT_I
        0xaa => { key: :j, meta: true }, # ALT_J
        0xab => { key: :k, meta: true }, # ALT_K
        0xac => { key: :l, meta: true }, # ALT_L
        0xad => { key: :m, meta: true }, # ALT_M
        0xae => { key: :n, meta: true }, # ALT_N
        0xaf => { key: :o, meta: true }, # ALT_O
        0xb0 => { key: :p, meta: true }, # ALT_P
        0xb1 => { key: :q, meta: true }, # ALT_Q
        0xb2 => { key: :r, meta: true }, # ALT_R
        0xb3 => { key: :s, meta: true }, # ALT_S
        0xb4 => { key: :t, meta: true }, # ALT_T
        0xb5 => { key: :u, meta: true }, # ALT_U
        0xb6 => { key: :v, meta: true }, # ALT_V
        0xb7 => { key: :w, meta: true }, # ALT_W
        0xb8 => { key: :x, meta: true }, # ALT_X
        0xb9 => { key: :y, meta: true }, # ALT_Y
        0xba => { key: :z, meta: true }, # ALT_Z
        0xcd => { key: :keypad_enter, meta: true }, # ALT_PADENTER
        0xd8 => { key: :keypad_plus, meta: true }, # ALT_PADPLUS
        0xd9 => { key: :keypad_minus, meta: true }, # ALT_PADMINUS
        0xda => { key: :keypad_divide, meta: true }, # ALT_PADSLASH
        0xdb => { key: :keypad_multiply, meta: true }, # ALT_PADSTAR
        0xdc => { key: :keypad_decimal, meta: true }, # ALT_PADSTOP
        0xde => { key: :delete, meta: true }, # ALT_DEL
        0xdf => { key: :insert, meta: true }, # ALT_INS
        0xe3 => { key: :tab, meta: true }, # ALT_TAB
        0xe4 => { key: "-".to_sym, meta: true }, # ALT_MINUS
        0xe5 => { key: "=".to_sym, meta: true }, # ALT_EQUAL
        0xe6 => { key: :home, meta: true }, # ALT_HOME
        0xe7 => { key: :page_up, meta: true }, # ALT_PGUP
        0xe8 => { key: :page_down, meta: true }, # ALT_PGDN
        0xe9 => { key: :end, meta: true }, # ALT_END
        0xea => { key: :up, meta: true }, # ALT_UP
        0xeb => { key: :down, meta: true }, # ALT_DOWN
        0xec => { key: :right, meta: true }, # ALT_RIGHT
        0xed => { key: :left, meta: true }, # ALT_LEFT
        0xee => { key: :enter, meta: true }, # ALT_ENTER
        0xef => { key: :escape, meta: true }, # ALT_ESC
        0xf0 => { key: "`".to_sym, meta: true }, # ALT_BQUOTE
        0xf1 => { key: "[".to_sym, meta: true }, # ALT_LBRACKET
        0xf2 => { key: "]".to_sym, meta: true }, # ALT_RBRACKET
        0xf3 => { key: ";".to_sym, meta: true }, # ALT_SEMICOLON
        0xf4 => { key: "'".to_sym, meta: true }, # ALT_FQUOTE
        0xf5 => { key: ",".to_sym, meta: true }, # ALT_COMMA
        0xf6 => { key: ".".to_sym, meta: true }, # ALT_STOP
        0xf7 => { key: "/".to_sym, meta: true }, # ALT_FSLASH
        0xf8 => { key: :backspace, meta: true }, # ALT_BKSP
        0x105 => { key: :keypad_0, meta: true }, # ALT_PAD0
        0x106 => { key: :keypad_1, meta: true }, # ALT_PAD1
        0x107 => { key: :keypad_2, meta: true }, # ALT_PAD2
        0x108 => { key: :keypad_3, meta: true }, # ALT_PAD3
        0x109 => { key: :keypad_4, meta: true }, # ALT_PAD4
        0x10a => { key: :keypad_5, meta: true }, # ALT_PAD5
        0x10b => { key: :keypad_6, meta: true }, # ALT_PAD6
        0x10c => { key: :keypad_7, meta: true }, # ALT_PAD7
        0x10d => { key: :keypad_8, meta: true }, # ALT_PAD8
        0x10e => { key: :keypad_9, meta: true }, # ALT_PAD9
        0x110 => { key: "\\".to_sym, meta: true }, # ALT_BSLASH
        0xbb => { key: :left, ctrl: true }, # CTL_LEFT
        0xbc => { key: :right, ctrl: true }, # CTL_RIGHT
        0xbd => { key: :page_up, ctrl: true }, # CTL_PGUP
        0xbe => { key: :page_down, ctrl: true }, # CTL_PGDN
        0xbf => { key: :home, ctrl: true }, # CTL_HOME
        0xc0 => { key: :end, ctrl: true }, # CTL_END
        0xcc => { key: :keypad_enter, ctrl: true }, # CTL_PADENTER
        0xd2 => { key: :keypad_decimal, ctrl: true }, # CTL_PADSTOP
        0xd3 => { key: :keypad_5, ctrl: true }, # CTL_PADCENTER
        0xd4 => { key: :keypad_plus, ctrl: true }, # CTL_PADPLUS
        0xd5 => { key: :keypad_minus, ctrl: true }, # CTL_PADMINUS
        0xd6 => { key: :keypad_divide, ctrl: true }, # CTL_PADSLASH
        0xd7 => { key: :keypad_multiply, ctrl: true }, # CTL_PADSTAR
        0xdd => { key: :insert, ctrl: true }, # CTL_INS
        0xe0 => { key: :up, ctrl: true }, # CTL_UP
        0xe1 => { key: :down, ctrl: true }, # CTL_DOWN
        0xe2 => { key: :tab, ctrl: true }, # CTL_TAB
        0xf9 => { key: :backspace, ctrl: true }, # CTL_BKSP
        0xfb => { key: :keypad_0, ctrl: true }, # CTL_PAD0
        0xfc => { key: :keypad_1, ctrl: true }, # CTL_PAD1
        0xfd => { key: :keypad_2, ctrl: true }, # CTL_PAD2
        0xfe => { key: :keypad_3, ctrl: true }, # CTL_PAD3
        0xff => { key: :keypad_4, ctrl: true }, # CTL_PAD4
        0x100 => { key: :keypad_5, ctrl: true }, # CTL_PAD5
        0x101 => { key: :keypad_6, ctrl: true }, # CTL_PAD6
        0x102 => { key: :keypad_7, ctrl: true }, # CTL_PAD7
        0x103 => { key: :keypad_8, ctrl: true }, # CTL_PAD8
        0x104 => { key: :keypad_9, ctrl: true }, # CTL_PAD9
        0x10f => { key: :delete, ctrl: true }, # CTL_DEL
        0x111 => { key: :enter, ctrl: true }, # CTL_ENTER
        0x112 => { key: :keypad_enter, shift: true }, # SHF_PADENTER
        0x113 => { key: :keypad_divide, shift: true }, # SHF_PADSLASH
        0x114 => { key: :keypad_multiply, shift: true }, # SHF_PADSTAR
        0x115 => { key: :keypad_plus, shift: true }, # SHF_PADPLUS
        0x116 => { key: :keypad_minus, shift: true }, # SHF_PADMINUS
        0x117 => { key: :up, shift: true }, # SHF_UP
        0x118 => { key: :down, shift: true }, # SHF_DOWN
        0x119 => { key: :insert, shift: true }, # SHF_IC
        0x11a => { key: :delete, shift: true }, # SHF_DC
        0x123 => { key: :up, shift: true }, # KEY_SUP
        0x124 => { key: :down, shift: true }, # KEY_SDOWN
      }.transform_values(&:freeze).freeze

      def self.events(offset)
        events = OFFSETS.to_h do |relative, spec|
          code = offset + relative
          [code, KeyEvent.new(**spec, raw: code)]
        end
        # The Windows backend encodes Shift/Ctrl/Alt F1-F12 as F13-F48.
        { shift: 12, ctrl: 24, meta: 36 }.each do |modifier, base|
          (1..12).each do |number|
            code = offset + 0x08 + base + number
            events[code] = KeyEvent.new(key: :"f#{number}", **{ modifier => true }, raw: code)
          end
        end
        events
      end
    end
  end
end
