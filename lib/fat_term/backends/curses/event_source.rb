# frozen_string_literal: true

require "curses"

module FatTerm
  module Backends
    module Curses
      class EventSource
        def initialize(window_provider:, key_decoder:)
          @window_provider = window_provider
          @key_decoder = key_decoder
        end

        def next_event
          raw = read_raw
          return unless raw

          @key_decoder.decode(raw) # => KeyEvent (or nil)
        end

        private

        def window
          @window_provider.call
        end

        def read_raw
          win = window
          return unless win

          ch = win.getch
          return unless ch

          if ch.is_a?(Integer) && ch == 27
            nxt = win.getch
            return 27 unless nxt

            [27, nxt]
          else
            ch
          end
        end
      end
    end
  end
end
