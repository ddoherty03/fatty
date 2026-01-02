# frozen_string_literal: true

require_relative 'keymaps/emacs'

module FatTerm
  class KeyMap
    def initialize
      @bindings = {}
    end

    def bind(key:, ctrl: false, meta: false, shift: false, action: nil)
      @bindings[[key, ctrl, meta, shift]] = action
    end

    def resolve(event)
      return unless event

      # Return the specific binding, or it there are none, the binding for the
      # unmodified key.  Thus C-Home will do the same thing as Home unless it
      # specifically is bound.
      @bindings[[event.key, event.ctrl?, event.meta?, event.shift?]] ||
        @bindings[[event.key, false, false, false]]
    end

    def load_config
      data = FatTerm::Config.keybindings
      return self unless data.is_a?(Array)

      data.each_with_index do |entry, idx|
        bind_entry(entry, idx)
      end
      self
    rescue Psych::SyntaxError => e
      warn "fat_term: syntax error in keybindings: #{e.message}"
      self
    end

    def bind_entry(entry, idx)
      unless entry.is_a?(Hash)
        warn "fat_term: invalid keybinding at index #{idx} (not a map)"
        return
      end

      key    = entry["key"]
      action = entry["action"]

      unless key && action
        warn "fat_term: missing key or action at index #{idx}"
        return
      end

      bind(
        key:    key.to_sym,
        ctrl:   entry["ctrl"]  || false,
        meta:   entry["meta"]  || false,
        shift:  entry["shift"] || false,
        action: action.to_sym,
      )
      self
    end
  end
end
