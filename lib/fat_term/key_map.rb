# frozen_string_literal: true

require_relative 'keymaps/emacs'

module FatTerm
  # The KeyMap class maintains the mapping between KeyEvent's and action names
  # that can be handled by Terminal.  Terminal can delegate the action to any
  # of its controlled components or handle the action itself.  Currently,
  # there are two contexts for KeyBinding: :input (for composing a line at the
  # Terminal) and :paging (for controlling the display of output that is
  # longer than the Viewport).  The default keybinding context is :input.
  class KeyMap
    DEFAULT_CONTEXT = :input

    def initialize
      @bindings = {}
    end

    # Bind a KeyEvent to an action in the given context.
    def bind(context: :input, key:, ctrl: false, meta: false, shift: false, action: nil)
      raise ArgumentError, "keybinding context must be :input or :paging" unless [:input, :paging].include?(context)
      raise ArgumentError, "context must be a Symbol" unless context.is_a?(Symbol)
      raise ArgumentError, "key must be a Symbol" unless key.is_a?(Symbol)
      raise ArgumentError, "action must be a Symbol" unless action.is_a?(Symbol)

      @bindings[[context, key, ctrl, meta, shift]] = action
    end

    # Return the action associated with the given KeyEvent in the given context.
    def resolve(event, context: :input)
      return unless event
      raise ArgumentError, "keybinding context must be a Symbol" unless context.is_a?(Symbol)
      raise ArgumentError, "keybinding context must be :input or :paging" unless [:input, :paging].include?(context)

      # Return the specific binding, or it there are none, the binding for the
      # unmodified key.  Thus C-Home will do the same thing as Home unless it
      # specifically is bound.
      @bindings[[context, event.key, event.ctrl?, event.meta?, event.shift?]] ||
        @bindings[[context, event.key, false, false, false]]
    end

    # Make the bindings from the user's config file, usually at
    # ~/.config/fat_term/keybindings.yml
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

    private

    # Make a binding from an entry Hash that has keys for context, key (the
    # unmodified key name), the modifiers, 'ctrl', 'meta', and 'shift'.  The
    # valid keynames, apart from all the printable characters on the keyboard,
    # are given in the constant FatTerm::CURSES_TO_EVENT map defined in the
    # curses_coder file.
    def bind_entry(entry, idx, default_context: DEFAULT_CONTEXT)
      unless entry.is_a?(Hash)
        warn "fat_term: invalid keybinding at index #{idx} (not a map)"
        return
      end

      key = entry["key"]
      action = entry["action"]
      ctx = entry.key?("context") ? entry["context"] : default_context

      unless key && action
        warn "fat_term: missing key or action at index #{idx}"
        return
      end

      bind(
        context: ctx.to_sym,
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
