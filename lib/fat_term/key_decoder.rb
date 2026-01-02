# frozen_string_literal: true

module FatTerm
  class KeyDecoder
    def initialize(env:, config:)
      @env = env
      @map = {}
      load_builtin_map
      load_user_config(config)
    end

    def decode(raw)
      return unless raw

      case raw
      when Array
        decode_meta(raw)
      else
        decode_single(raw)
      end
    end

    def fallback_decode(ch)
      case ch
      when Integer
        if ch == 27
          decode_meta(ch)
        elsif (0..26).include?(ch)
          KeyEvent.new(key: (ch + 96).chr.to_sym, ctrl: true, raw: ch)
        else
          KeyEvent.new(key: ch, raw: ch)
        end
      when String
        KeyEvent.new(key: ch.to_sym, text: ch, raw: ch)
      end
    end

    def decode_meta((esc, nxt))
      case nxt
      when String
        KeyEvent.new(
          key: nxt.to_sym,
          text: nxt,
          meta: true,
          raw: [esc, nxt],
        )
      when Integer
        if @map.key?(nxt)
          evt = @map[nxt].dup
          evt.meta = true
          evt.raw  = [esc, nxt]
          evt
        else
          KeyEvent.new(key: nxt, meta: true, raw: [esc, nxt])
        end
      end
    end

    def decode_single(ch)
      if ch.is_a?(Integer) && @map.key?(ch)
        @map[ch]
      else
        fallback_decode(ch)
      end
    end

    def load_user_config(config)
      return unless config

      terminal = @env[:terminal]
      section  = config.dig("terminal", terminal.to_s, "map")
      return unless section

      section.each do |code, spec|
        @map[Integer(code)] = KeyEvent.new(**normalize_spec(spec))
      end
    end

    def load_builtin_map
      CURSES_TO_EVENT.each do |code, event|
        @map[code] = event
      end
    end

    def normalize_spec(hash)
      spec = hash.transform_keys(&:to_sym)
      if spec[:key].is_a?(String)
        spec[:key] = spec[:key].to_sym
      end
      spec
    end
  end
end
