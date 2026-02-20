# frozen_string_literal: true

require_relative 'keymaps/emacs'

module FatTerm
  # This struct is used as a key into the KeyMap.  It represents only those
  # parts of the KeyEvent that are relevant for resolving bindings.  It also
  # normalizes the use of uppercase letters, like 'G' to convert them to a
  # canonical :g with shift: true.  That way the user can bind either to mean
  # the same thing.
  KeyGesture = Struct.new(:key, :ctrl, :meta, :shift, keyword_init: true) do
    def self.from_event(ev)
      k = ev&.key
      ctrl = !!ev&.ctrl
      meta = !!ev&.meta
      shift = !!ev&.shift

      if k.is_a?(Symbol)
        s = k.to_s
        if s.length == 1
          ch = s[0]
          if ('A'..'Z').cover?(ch)
            # Decoder (or config) used :G. Canonicalize to :g + shift.
            k = ch.downcase.to_sym
            shift = true
          elsif ('a'..'z').cover?(ch)
            # Decoder used :g. Keep it, but allow explicit shift to mean uppercase.
            k = ch.to_sym
          end
        end
      end

      new(key: k, ctrl: ctrl, meta: meta, shift: shift)
    end
  end

  # The KeyMap class maintains the mapping between KeyEvent's and action names
  # that can be handled by Terminal.  Terminal can delegate the action to any
  # of its controlled components or handle the action itself.  Currently,
  # there are two contexts for KeyBinding: :input (for composing a line at the
  # Terminal) and :paging (for controlling the display of output that is
  # longer than the Viewport).  The default keybinding context is :input.
  class KeyMap
    attr_reader :bindings

    DEFAULT_CONTEXT = :input

    def self.registered_contexts
      @registered_contexts ||= [DEFAULT_CONTEXT, :paging]
    end

    # Register a context (optionally before/after another for precedence/printing)
    def self.register_context(ctx, before: nil, after: nil)
      ctx = ctx.to_s.to_sym
      list = registered_contexts
      return ctx if list.include?(ctx)

      if before
        i = list.index(before.to_s.to_sym) || 0
        list.insert(i, ctx)
      elsif after
        i = list.index(after.to_s.to_sym)
        i ? list.insert(i + 1, ctx) : list << ctx
      else
        list << ctx
      end

      ctx
    end

    def initialize
      @bindings = Hash.new { |h, ctx| h[ctx] = {} }
    end

    # Bind a KeyEvent to an action in the given context.
    def bind(context: :input, key:, ctrl: false, meta: false, shift: false, action: nil)
      arg_str = "context: #{context}, key: #{key}, ctrl: #{ctrl}, meta: #{meta}, shift: #{shift}, action: #{action}"
      FatTerm.log("KeyMap#bind(#{arg_str})", tag: :keybinding)

      raise ArgumentError, "context must be a Symbol" unless context.is_a?(Symbol)
      raise ArgumentError, "key must be a Symbol" unless key.is_a?(Symbol)
      unless action.is_a?(Symbol) || (action.is_a?(Array) && action.first.is_a?(Symbol))
        raise ArgumentError, "action must be a Symbol or [Symbol, *args]"
      end

      self.class.register_context(context)

      evt = KeyEvent.new(
        key:,
        ctrl: truthy?(ctrl),
        meta: truthy?(meta),
        shift: truthy?(shift),
      )
      gest = KeyGesture.from_event(evt)
      @bindings[context][gest] = action
    end

    # Return the action associated with the given KeyEvent in the given contexts.
    def resolve(event, contexts: [])
      return unless event

      gest = KeyGesture.from_event(event)
      arg_str = "event: #{event}, gesture: #{gest}, contexts: #{contexts}"
      FatTerm.log("KeyMap#resolve(#{arg_str})", tag: :keybinding)

      ctxs = normalize_contexts(contexts)
      result = nil
      ctxs.each do |ctx|
        map = @bindings.fetch(ctx, nil)
        next unless map

        result = map[gest]
        break if result
      end
      FatTerm.log("KeyMap.resolve: -> #{result.inspect}", tag: :keybinding)
      result
    end

    # Return [action, args] where args is always an Array (possibly empty).
    def resolve_action(event, contexts: [])
      binding = resolve(event, contexts: contexts)

      if binding
        if binding.is_a?(Array)
          action = binding[0]
          args = binding[1..] || []
          FatTerm.log("KeyMap.resolve_action: action: #{action.inspect}, args: #{args.inspect}", tag: :keymap)
          [action, args]
        else
          FatTerm.log("KeyMap.resolve_action: action: #{binding.inspect}, args: []", tag: :keymap)
          [binding, []]
        end
      elsif event&.printable? && (contexts.include?(:input) || contexts.include?(:pager_input))
        # Default: treat printable characters as a self-insert but only in
        # those contexts designed to take text input, not contexts like
        # :paging where keys are meant for control.
        [:self_insert, [event.text]]
      else
        [nil, []]
      end
    end

    # Return all contexts currently used in this instance
    def contexts
      @bindings.keys
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

    # Allow the user to supply an empty Array or nil to search all contexts.
    def normalize_contexts(contexts)
      case contexts
      when Array
        if contexts.empty?
          self.class.registered_contexts
        else
          contexts.compact.map { |c| c.to_s.to_sym }
        end
      when String, Symbol
        [contexts.to_s.to_sym]
      when NilClass
        self.class.registered_contexts
      else
        raise ArgumentError, "contexts must be Symbol/String, Array, or nil"
      end
    end

    def truthy?(str)
      return false unless str
      return true if str == true
      return true if str.to_s.match?(/\At/i)

      false
    end
  end
end
