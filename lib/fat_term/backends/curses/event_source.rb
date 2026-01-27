# frozen_string_literal: true

module FatTerm
  module Backends
    module Curses
      class EventSource
        attr_reader :context, :key_decoder

        def initialize(context:, key_decoder:)
          @context = context
          @key_decoder = key_decoder
        end

        def next_event
          raw = read_raw
          return unless raw

          @key_decoder.decode(raw) # => KeyEvent (or nil)
        end

        private

        def window
          context.input_win
        end

        def read_raw
          return unless window

          ch = window.getch
          return unless ch

          if ch.is_a?(Integer) && ch == 27
            nxt = window.getch
            return ch unless nxt

            [ch, nxt]
          else
            ch
          end
        end
      end
    end
  end
end
