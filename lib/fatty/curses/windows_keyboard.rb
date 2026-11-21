# frozen_string_literal: true

require "fiddle"

module Fatty
  module Curses
    # PDCurses collapses left/right Alt into one flag. Consult the keyboard
    # layout to preserve characters that actually require Ctrl+Alt (AltGr).
    module WindowsKeyboard
      def self.altgr_character?(text)
        return true unless Gem.win_platform?
        return true unless text.length == 1 && text.ord <= 0xffff

        mapping = key_scan.call(text.ord)
        # Unknown/composed characters stay text rather than becoming shortcuts.
        mapping == -1 || ((mapping >> 8) & 6) == 6
      rescue Fiddle::DLError
        true
      end

      def self.key_scan
        @key_scan ||= begin
          library = Fiddle.dlopen("user32.dll")
          abi = if Fiddle::Function.const_defined?(:STDCALL)
            Fiddle::Function::STDCALL
          else
            Fiddle::Function::DEFAULT
          end
          Fiddle::Function.new(library["VkKeyScanW"], [Fiddle::TYPE_SHORT], Fiddle::TYPE_SHORT, abi)
        end
      end
      private_class_method :key_scan
    end
  end
end
