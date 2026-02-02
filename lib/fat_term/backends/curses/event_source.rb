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

          ev = @key_decoder.decode(raw)
          return unless ev

          [:key, ev]
        end

        private

        def window
          context.input_win
        end

        def read_raw
          return unless window

          ch = window.getch
          FatTerm.log(:curses_getch,
                      ch_class: ch.class.name,
                      ch_inspect: ch.inspect,
                      ch_int: (ch.is_a?(Integer) ? ch : nil),
                      ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil)
                     )
          return unless ch

          if ch.is_a?(Integer) && ch == 27
            nxt = window.getch
            FatTerm.log(:curses_getch,
                        ch_class: ch.class.name,
                        ch_inspect: ch.inspect,
                        ch_int: (ch.is_a?(Integer) ? ch : nil),
                        ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil)
                       )
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
