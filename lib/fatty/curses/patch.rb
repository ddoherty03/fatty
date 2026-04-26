# frozen_string_literal: true

# This is here to supress a particular warning that is emitted by Curses mouse
# code.
module Warning
  class << self
    alias_method :fat_term_orig_warn, :warn unless method_defined?(:fat_term_orig_warn)

    def warn(msg, category: nil, **kwargs)
      return if msg.include?("undefining the allocator of T_DATA class Curses::MouseEvent")

      fat_term_orig_warn(msg, category: category, **kwargs)
    end
  end
end

# Curses button-related constants:
#
# * Button1 (Left button)
# BUTTON1_PRESSED         0x00000002
# BUTTON1_RELEASED        0x00000001
# BUTTON1_CLICKED         0x00000004
# BUTTON1_DOUBLE_CLICKED  0x00000008
# BUTTON1_TRIPLE_CLICKED  0x00000010
#
# * Button2 (Middle button)
# BUTTON2_PRESSED         0x00000080
# BUTTON2_RELEASED        0x00000040
# BUTTON2_CLICKED         0x00000100
# BUTTON2_DOUBLE_CLICKED  0x00000200
# BUTTON2_TRIPLE_CLICKED  0x00000400
#
# * Button3 (Right button)
# BUTTON3_PRESSED         0x00002000
# BUTTON3_RELEASED        0x00001000
# BUTTON3_CLICKED         0x00004000
# BUTTON3_DOUBLE_CLICKED  0x00008000
# BUTTON3_TRIPLE_CLICKED  0x00010000
#
# * Button4 (wheel up)
# BUTTON4_PRESSED         0x00020000
# BUTTON4_RELEASED        0x00040000
# BUTTON4_CLICKED         0x00080000
# BUTTON4_DOUBLE_CLICKED  0x00100000
# BUTTON4_TRIPLE_CLICKED  0x00200000
#
# * Button5 (wheel down)
# BUTTON5_PRESSED         0x00200000
# BUTTON5_RELEASED        0x00400000
# BUTTON5_CLICKED         0x00800000
# BUTTON5_DOUBLE_CLICKED  0x01000000
# BUTTON5_TRIPLE_CLICKED  0x02000000
#
# * Modifier Flags
# BUTTON_SHIFT  0x04000000
# BUTTON_CTRL   0x08000000
# BUTTON_ALT    0x10000000
#
# The ruby implementation of curses apparently does not expose some
# mouse-related constants.  Here we provide a method to ensure that they are
# defined.
module FatTerm
  module Curses
    module MouseConstants
      CONSTANTS = {
        # Button 1 (left)
        BUTTON1_RELEASED:        0x00000001,
        BUTTON1_PRESSED:         0x00000002,
        BUTTON1_CLICKED:         0x00000004,
        BUTTON1_DOUBLE_CLICKED:  0x00000008,
        BUTTON1_TRIPLE_CLICKED:  0x00000010,

        # Button 2 (middle)
        BUTTON2_RELEASED:        0x00000040,
        BUTTON2_PRESSED:         0x00000080,
        BUTTON2_CLICKED:         0x00000100,
        BUTTON2_DOUBLE_CLICKED:  0x00000200,
        BUTTON2_TRIPLE_CLICKED:  0x00000400,

        # Button 3 (right)
        BUTTON3_RELEASED:        0x00001000,
        BUTTON3_PRESSED:         0x00002000,
        BUTTON3_CLICKED:         0x00004000,
        BUTTON3_DOUBLE_CLICKED:  0x00008000,
        BUTTON3_TRIPLE_CLICKED:  0x00010000,

        # Wheel up
        BUTTON4_PRESSED:         0x00020000,
        BUTTON4_RELEASED:        0x00040000,
        BUTTON4_CLICKED:         0x00080000,
        BUTTON4_DOUBLE_CLICKED:  0x00100000,
        BUTTON4_TRIPLE_CLICKED:  0x00200000,

        # Wheel down
        BUTTON5_PRESSED:         0x00200000,
        BUTTON5_RELEASED:        0x00400000,
        BUTTON5_CLICKED:         0x00800000,
        BUTTON5_DOUBLE_CLICKED:  0x01000000,
        BUTTON5_TRIPLE_CLICKED:  0x02000000,

        # Modifier masks
        BUTTON_SHIFT:            0x04000000,
        BUTTON_CTRL:             0x08000000,
        BUTTON_ALT:              0x10000000,
      }.freeze

      def self.ensure!
        CONSTANTS.each do |name, value|
          next if ::Curses.const_defined?(name)

          ::Curses.const_set(name, value)
        end
      end
    end
  end
end
