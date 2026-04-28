# frozen_string_literal: true

module Fatty
  # The KeyEvent class is a simple class to store a key with its modifiers.
  # KeyMap will map a KeyEvent to an action (for a given context), and the
  # KeyDecoder class is responsible for turning raw key inputs from curses
  # into a KeyEvent.  The CURSES_TO_EVENT constant is an initial map from
  # known curses key codes to KeyEvents.  These can be overriden for different
  # terminals in Fatty::Config.keydefs.
  class KeyEvent
    CTRL_CODE_TO_LETTER = (1..26).each_with_object({}) { |n, h|
      # 1->:a, 2->:b, ... 21->:u, 23->:w
      h[n] = (96 + n).chr.to_sym
    }.freeze

    CTRL_PUNCT = {
      27 => :'[',   # ESC is also C-[
      28 => :'\\',  # C-\
      29 => :']',   # C-]
      30 => :'^',   # C-^
      31 => :'/',   # C-_
    }.freeze

    private_constant :CTRL_CODE_TO_LETTER

    attr_reader :key, :text, :ctrl, :meta, :shift, :raw

    def initialize(key:, text: nil, raw: nil, ctrl: false, meta: false, shift: false)
      # If the decoder gives us a control character as an integer (1..26),
      # canonicalize it to ctrl+letter so keymaps and display behave nicely.
      if key.is_a?(Integer)
        if CTRL_CODE_TO_LETTER.key?(key)
          key = CTRL_CODE_TO_LETTER[key]
          ctrl = true
        elsif CTRL_PUNCT.key?(key)
          key = CTRL_PUNCT[key]
          ctrl = true
        end
      end
      @key = key           # Symbol or named key
      @raw = raw           # the key (or keys for escape sequences) as returned by Curses
      @ctrl = ctrl
      @meta = meta
      @shift = shift
      # invariant: chorded keys do not self-insert
      @text = ctrl || meta ? nil : text
    end

    def self.key_to_str(key: "<?>", ctrl: false, meta: false, shift: false)
      mods = []
      mods << "C" if ctrl
      mods << "M" if meta
      mods << "S" if shift
      key_str = key.to_s
      mods.empty? ? key_str : "#{mods.join('-')}-#{key_str}"
    end

    def to_s
      self.class.key_to_str(key:, ctrl:, meta:, shift:)
    end

    def ==(other)
      other.is_a?(KeyEvent) &&
        key == other.key &&
        ctrl == other.ctrl &&
        meta == other.meta &&
        shift == other.shift
    end
    alias_method :eql?, :==

    def hash
      [key, ctrl, meta, shift].hash
    end

    def printable?
      text && !text.empty? && text != "\n" && text != "\r"
    end

    def coded?
      key.is_a?(Symbol)
    end

    def uncoded?
      !key.is_a?(Symbol)
    end

    def bindings
      Fatty::KeyMap.active.bindings_for(self) || {}
    end

    def unbound?
      coded? && bindings.empty?
    end

    def key_name
      coded? ? to_s : "(none)"
    end

    def code
      case raw
      when Integer
        raw
      when Array
        raw.reverse.find { |item| item.is_a?(Integer) }
      end
    end

    def raw_bytes
      bytes_from_raw(raw)
    end

    def bytes_from_raw(value)
      case value
      when Array
        value.flat_map { |item| bytes_from_raw(item) }
      when String
        value.bytes
      when Integer
        [value]
      else
        []
      end
    end

    def modifier_text
      mods = []
      mods << "ctrl" if ctrl?
      mods << "meta" if meta?
      mods << "shift" if shift?
      mods.empty? ? "(none)" : mods.join(", ")
    end

    def bindings_text
      return "(none)" if bindings.empty?

      text = bindings.map do |context, binding|
        "    context: #{context}: #{binding_text(binding)}"
      end.join("\n")
      text
    end

    def binding_text(binding)
      case binding
      when nil
        "(none)"
      when Array
        action = binding[0]
        args = binding[1..] || []
        args.empty? ? action.inspect : "#{action.inspect} #{args.inspect}"
      else
        binding.inspect
      end
    end

    def color
      if uncoded?
        :oops
      elsif unbound?
        :warn
      else
        :good
      end
    end

    def status_string
      if uncoded?
        "(UNCODED)"
      elsif unbound?
        "(UNBOUND)"
      else
        "(BOUND)"
      end
    end

    def ctrl?
      @ctrl
    end

    def meta?
      @meta
    end

    def shift?
      @shift
    end

    def report
      if uncoded?
        report_for_uncoded
      elsif unbound?
        report_for_unbound
      else
        report_for_bound
      end
    end

    def report_for_uncoded
      rule = colorize("=" * 55) + "\n"
      out = +""
      out << rule
      out << colorize("Key report #{status_string}:\n")
      out << "  code:      #{code.inspect}\n"
      out << "  raw:       #{raw.inspect}\n"
      out << "  bytes:     #{raw_bytes.inspect}\n"
      out << "  key:       #{key.inspect}\n"
      out << "\n"

      # snippet = suggested_keydef
      # @suggestions << snippet
      # out << "\n"
      # out << snippet
      # out << "\n"
    end

    def report_for_unbound
      rule = colorize("=" * 55) + "\n"
      out = +""
      out << rule
      out << colorize("Key report #{status_string}:\n")
      # out << "  TERM:      #{terminal_name}\n"
      out << "  code:      #{code.inspect}\n"
      out << "  raw:       #{raw.inspect}\n"
      out << "  bytes:     #{raw_bytes.inspect}\n"
      out << "  key:       #{key.inspect}\n"
      out << "  name:      #{key_name}\n"
      out << "  text:      #{text.inspect}\n"
      out << "  modifiers: #{modifier_text}\n"

      # snippet = suggested_keybinding(ev)
      # @suggestions << snippet
      # out << "\n"
      # out << snippet
      # out << "\n"
    end

    def report_for_bound
      rule = colorize("=" * 55) + "\n"
      out = +""
      out << rule
      out << colorize("Key report #{status_string}:\n")
      # out << "  TERM:      #{terminal_name}\n"
      out << "  code:      #{code.inspect}\n"
      out << "  raw:       #{raw.inspect}\n"
      out << "  bytes:     #{raw_bytes.inspect}\n"
      out << "  key:       #{key.inspect}\n"
      out << "  name:      #{key_name}\n"
      out << "  text:      #{text.inspect}\n"
      out << "  modifiers: #{modifier_text}\n"
      out << "  bindings:\n#{bindings_text}\n"
      out << "\n"
    end

    def colorize(text)
      case color
      when :good
        Rainbow(text).green
      when :warn
        Rainbow(text).yellow
      when :oops
        Rainbow(text).red
      else
        text
      end
    end

    def suggested_snippet(terminal_name)
      if uncoded?
        suggested_keydef(terminal_name)
      elsif unbound?
        suggested_keybinding
      else
        ''
      end
    end

    def suggested_keydef(terminal_name)
      return "" unless code

      <<~TEXT

        No key name is associated with this keycode.

        Suggested keydefs.yml entry:

        #{terminal_name}:
          map:
            #{code}:
              key: key_name
              shift: <true/false>
              ctrl: <true/false>
              meta: <true/false>
      TEXT
    end

    def suggested_keybinding
      <<~TEXT

        No action is bound to #{key_name}.

        Suggested keybindings.yml entry:

        - key: #{key_name}
          action: <action-name>
      TEXT
    end
  end
end
