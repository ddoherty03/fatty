# frozen_string_literal: true

module FatTerm
  module Backends
    module Curses
      class EventSource
        attr_reader :context, :key_decoder

        def initialize(context:, key_decoder:, poll_ms: 200)
          @context = context
          @key_decoder = key_decoder
          @poll_ms = poll_ms.to_i
          configure_input_polling!
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

        def configure_input_polling!
          win = window
          return unless win

          # Make getch return nil periodically so Terminal can keep rendering,
          # which allows PTY output appended from background threads to appear.
          win.timeout = @poll_ms if win.respond_to?(:timeout=)
        end

        def read_raw
          return unless window

          # The input window can be replaced when the layout changes (resize,
          # apply_layout, etc.). Ensure polling is always enabled on the
          # current window so getch doesn't block and Terminal can tick.
          window.timeout = @poll_ms if window.respond_to?(:timeout=)

          ch = window.getch
          return if ch == -1
          return unless ch

          if FatTerm::Config.config.dig(:log, :tags)&.include?(:keycode)
            FatTerm.debug(:curses_getch,
                          tag: :keycode,
                          ch_class: ch.class.name,
                          ch_inspect: ch.inspect,
                          ch_int: (ch.is_a?(Integer) ? ch : nil),
                          ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil)
                         )
          end

          if ch.is_a?(Integer) && ch == 27
            nxt = window.getch
            return if ch == -1

            if FatTerm::Config.config.dig(:log, :tags)&.include?(:keycode)
              FatTerm.log(:curses_getch,
                          tag: :keycode,
                          ch_class: ch.class.name,
                          ch_inspect: ch.inspect,
                          ch_int: (ch.is_a?(Integer) ? ch : nil),
                          ch_chr: (ch.is_a?(Integer) && ch.between?(0, 255) ? ch.chr : nil)
                         )
            end
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
