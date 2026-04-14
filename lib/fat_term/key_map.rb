# frozen_string_literal: true

require_relative 'keymaps/emacs'

module FatTerm
  # This struct is used as a key into the KeyMap.  It represents only those
  # parts of the KeyEvent that are relevant for resolving bindings.  It also
  # normalizes the use of uppercase letters, like 'G' to convert them to a
  # canonical :g with shift: true.  That way the user can bind either to mean
  # the same thing.
  # KeyGesture = Struct.new(:key, :ctrl, :meta, :shift, keyword_init: true) do
  class KeyGesture
    attr_reader :key, :ctrl, :meta, :shift

    def initialize(key:, ctrl:, meta:, shift:)
      @key = key
      @ctrl = ctrl
      @meta = meta
      @shift = shift
    end

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

    def ==(other)
      other.is_a?(self.class) &&
        key == other.key &&
        ctrl == other.ctrl &&
        meta == other.meta &&
        shift == other.shift
    end
    alias_method :eql?, :==

    def hash
      [self.class, key, ctrl, meta, shift].hash
    end

    def inspect
      "#<#{self.class} key=#{key.inspect} ctrl=#{ctrl} meta=#{meta} shift=#{shift}>"
    end
  end

  class MouseGesture
    attr_reader :button, :ctrl, :meta, :shift

    def initialize(button:, ctrl:, meta:, shift:)
      @button = button
      @ctrl = ctrl
      @meta = meta
      @shift = shift
    end

    def self.from_event(event)
      new(
        button: event.button,
        ctrl: !!event.ctrl,
        meta: !!event.meta,
        shift: !!event.shift,
      )
    end

    def ==(other)
      other.is_a?(self.class) &&
        button == other.button &&
        ctrl == other.ctrl &&
        meta == other.meta &&
        shift == other.shift
    end
    alias_method :eql?, :==

    def hash
      [self.class, button, ctrl, meta, shift].hash
    end

    def inspect
      "#<#{self.class} button=#{button.inspect} ctrl=#{ctrl} meta=#{meta} shift=#{shift}>"
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
      bind_str = "#{KeyEvent.key_to_str(key:, ctrl:, meta:, shift:)} -> #{action} in context: #{context}"
      FatTerm.info("KeyMap#bind: (#{bind_str})", tag: :keybinding)

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
      self
    end

    def bind_mouse(context: :input, button:, ctrl: false, meta: false, shift: false, action: nil)
      bind_str = "#{KeyEvent.key_to_str(key: button, ctrl:, meta:, shift:)} -> #{action} in context: #{context}"
      FatTerm.info("KeyMap#bind_mouse(#{bind_str})", tag: :keybinding)

      raise ArgumentError, "context must be a Symbol" unless context.is_a?(Symbol)
      raise ArgumentError, "button must be a Symbol" unless button.is_a?(Symbol)
      unless action.is_a?(Symbol) || (action.is_a?(Array) && action.first.is_a?(Symbol))
        raise ArgumentError, "action must be a Symbol or [Symbol, *args]"
      end

      self.class.register_context(context)

      gest = MouseGesture.new(
        button: button,
        ctrl: truthy?(ctrl),
        meta: truthy?(meta),
        shift: truthy?(shift),
      )
      @bindings[context][gest] = action
      self
    end

    def resolve(event, contexts: [])
      return unless event

      ctxs = normalize_contexts(contexts)
      gest = gesture_from_event(event)

      result = nil
      ctxs.each do |ctx|
        map = @bindings.fetch(ctx, nil)
        next unless map

        result = map[gest]
        break if result
      end
      map_str = "#{event} -> #{result.inspect} in contexts: #{contexts} "
      FatTerm.debug("KeyMap#resolve: #{map_str}", tag: :keybinding)
      result
    end

    # Return [action, args] where args is always an Array (possibly empty).
    def resolve_action(event, contexts: [])
      binding = resolve(event, contexts: contexts)

      if binding
        if binding.is_a?(Array)
          action = binding[0]
          args = binding[1..] || []
          FatTerm.debug("KeyMap.resolve_action: action: #{action.inspect}, args: #{args.inspect}", tag: :keybinding)
          [action, args]
        else
          FatTerm.debug("KeyMap.resolve_action: action: #{binding.inspect}, args: []", tag: :keybinding)
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
    def load_user_config
      FatTerm.info("Read keybindings from #{Config.user_keybindings_path}", tag: :keybinding)
      data = FatTerm::Config.keybindings
      return self unless data.is_a?(Array)

      FatTerm.info("User keybindings", config: data, tag: :keybinding)
      data.each_with_index do |entry, idx|
        bind_entry(entry, idx)
      end
      self
    rescue Psych::SyntaxError => e
      FatTerm.error("KeyMap#load_config syntax error in keybindings: #{e.message}", tag: :keybinding)
      self
    end

    # Bind the digits in the given context with either meta, ctrl, neither or
    # both as the required modifier keys.
    def bind_digits(context: :input, meta: nil, ctrl: nil)
      meta = !!meta
      ctrl = !!ctrl
      (0..9).each do |n|
        bind(
          context: context,
          key: n.to_s.to_sym,
          meta: meta,
          ctrl: ctrl,
          action: [:count_digit, n],
        )
      end
    end

    private

    def gesture_from_event(event)
      case event
      when FatTerm::MouseEvent
        MouseGesture.from_event(event)
      else
        KeyGesture.from_event(event)
      end
    end

    # Make a binding from an entry Hash that has keys for context, key (the
    # unmodified key name), the modifiers, 'ctrl', 'meta', and 'shift'.  The
    # valid keynames, apart from all the printable characters on the keyboard,
    # are given in the constant FatTerm::CURSES_TO_EVENT map defined in the
    # curses_coder file.
    def bind_entry(entry, idx, default_context: DEFAULT_CONTEXT)
      unless entry.is_a?(Hash)
        FatTerm.error("KeyMap#bind_entry invalid keybinding at index #{idx} (not a map)", tag: :keybinding)
        return
      end

      key = entry["key"] || entry[:key]
      button = entry["button"] || entry[:button]
      action = entry["action"] || entry[:action]
      ctx =
        if entry.key?("context")
          entry["context"]
        elsif entry.key?(:context)
          entry[:context]
        else
          default_context
        end

      unless (key || button) && action
        FatTerm.error(
          "KeyMap#bind_entry missing key/button or action for context `#{ctx}` at index #{idx}",
          tag: :keybinding,
        )
        return
      end

      if button
        bind_mouse(
          context: ctx.to_sym,
          button: button.to_sym,
          ctrl:  entry["ctrl"]  || entry[:ctrl]  || false,
          meta:  entry["meta"]  || entry[:meta]  || false,
          shift: entry["shift"] || entry[:shift] || false,
          action: action.to_sym,
        )
      else
        bind(
          context: ctx.to_sym,
          key:    key.to_sym,
          ctrl:   entry["ctrl"]  || entry[:ctrl]  || false,
          meta:   entry["meta"]  || entry[:meta]  || false,
          shift:  entry["shift"] || entry[:shift] || false,
          action: action.to_sym,
        )
      end
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
