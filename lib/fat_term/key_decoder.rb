# frozen_string_literal: true

module FatTerm
  class KeyDecoder
    def initialize(env:, config:)
      @env = env
      @map = {}
      load_builtin_map
      load_user_config(config)
    end

    def decode(ch)
      return unless ch

      if ch.is_a?(Integer) && @map.key?(ch)
        @map[ch]
      else
        fallback_decode(ch)
      end
    end

    def fallback_decode(ch)
      case ch
      when Integer
        if ch == 27
          decode_meta
        elsif (0..26).include?(ch)
          KeyEvent.new(key: (ch + 96).chr.to_sym, ctrl: true, raw: ch)
        else
          KeyEvent.new(key: ch, raw: ch)
        end
      when String
        KeyEvent.new(key: ch.to_sym, text: ch, raw: ch)
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
