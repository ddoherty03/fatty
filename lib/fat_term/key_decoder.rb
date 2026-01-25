# frozen_string_literal: true

module FatTerm
  # The KeyDecoder class is responsible for converting raw key events returned
  # by the curses library into KeyEvent's to be used by FatTerm. This allows
  # FatTerm to deal with keyboard actions using friendly names, like
  # :home. :page_down, :f5, and so forth.  It also sets the modifiers, :shift,
  # :ctrl, and :meta, in the KeyEvent so that the KeyMap can assign different
  # actions to the modified keys.
  class KeyDecoder
    def initialize(env:)
      @env = env
      @map = {}
      load_builtin_map
      load_user_config
    end

    # Return a KeyEvent object based on the raw keyboard input as returned by
    # Screen#read_raw.
    def decode(raw)
      return unless raw

      case raw
      when Array
        decode_meta(raw)
      else
        decode_single(raw)
      end
    end

    private

    # Handle the decoding of meta keys which are returned as an Array of the
    # escape code followed by another key, nxt, which can be either a String
    # or an Integer.
    def decode_meta((esc, nxt))
      case nxt
      when String
        # Meta + printable => action key, not self-insert
        KeyEvent.new(
          key:  nxt.to_sym,
          meta: true,
          raw:  [esc, nxt],
        )
      when Integer
        # Meta + NUL => Meta-Ctrl-@
        if nxt == 0
          return KeyEvent.new(
                   key:  :"@",
                   ctrl: true,
                   meta: true,
                   raw:  [esc, nxt],
                 )
        end

        if (base = @map[nxt])
          KeyEvent.new(
            key:   base.key,
            ctrl:  base.ctrl?,
            shift: base.shift?,
            meta:  true,
            raw:   [esc, nxt],
          )
        else
          KeyEvent.new(key: nxt, meta: true, raw: [esc, nxt])
        end
      end
    end

    # Decode a raw input returned as a single character rather than an Array.
    # The single character might be the ASCII ESCAPE (27), in which case, we
    # have a meta sequence that needs handling.
    def decode_single(ch)
      if ch.is_a?(Integer) && @map.key?(ch)
        @map[ch]
      else
        fallback_decode(ch)
      end
    end

    def fallback_decode(ch)
      case ch
      when Integer
        if ch == 0
          # Ctrl-@ => NUL
          KeyEvent.new(key: :'@', ctrl: true, raw: ch)
        elsif (1..26).cover?(ch)
          KeyEvent.new(key: (ch + 96).chr.to_sym, ctrl: true, raw: ch)
        elsif ch == 27
          KeyEvent.new(key: :escape, raw: ch)
        else
          KeyEvent.new(key: ch, raw: ch)
        end
      when String
        key =
          case ch
          when " "  then :space
          when "\t" then :tab
          when "\n", "\r" then :enter
          else
            # bindable “literal” key, e.g. "h" => :h, "x" => :x, "." => :"."
            ch.to_sym
          end
        KeyEvent.new(key: key, text: ch, raw: ch)
      end
    end

    # Add to the @map any keydefs defined by the user for the terminal
    # detected in the environment.  The user config, usually in
    # ~/.config/fat_term/keydefs.yml, takes into account the vagaries of how
    # different terminal programs process keys.
    def load_user_config
      config = FatTerm::Config.keydefs
      return unless config

      terminal = @env[:terminal]
      section  = config.dig(:terminal, terminal.to_sym, :map)
      return unless section

      section.each do |code, spec|
        @map[Integer(code)] = KeyEvent.new(**normalize_spec(spec))
      end
    end

    # Add to the @map keydefs as assumed by the curses library, defined in the
    # constant FatTerm::CUSRSES_TO_EVENT.  These can be overridden by the the
    # user config in #load_user_config.
    def load_builtin_map
      CURSES_TO_EVENT.each do |code, event|
        @map[code] = event
      end
    end

    # Make sure the user config Hash uses symbols for its keys.  Return the
    # Hash as so corrected.
    def normalize_spec(hash)
      spec = hash.transform_keys(&:to_sym)
      if spec[:key].is_a?(String)
        spec[:key] = spec[:key].to_sym
      end
      spec
    end
  end
end
