# frozen_string_literal: true

module FatTerm
  # Base class for stateful controllers in the Terminal runtime.
  #
  # Sessions:
  # - own mutable state (the "Model")
  # - receive semantic Events (KeyEvent/MouseEvent/ResizeEvent/etc.)
  # - update state via Actions (Actionable) or direct Ruby methods
  # - may enqueue commands for the runtime to perform (side effects)
  #
  # This is intentionally lightweight; it sets conventions and provides
  # helpers, without forcing strict FP/MVU.
  class Session
    # The current keymap for this session (used by the runtime when routing
    # events to actions).  Allow the runtime to change this.
    attr_accessor :keymap

    # Views owned by this session (pure renderers).
    attr_reader :views

    # Runtime commands emitted by this session.
    attr_reader :commands

    # Context symbol used when resolving bindings (e.g., :input, :paging,
    # :completion). The runtime is free to override.
    attr_accessor :context

    def initialize(keymap: nil, context: :default, views: [])
      @keymap = keymap
      @context = context.to_sym
      @views = Array(views)
      @commands = []
      @active = true
    end

    def active?
      @active
    end

    def focus!
      @active = true
      self
    end

    def blur!
      @active = false
      self
    end

    # Enqueue a command for the runtime. Commands are opaque to Session; they
    # are interpreted by Terminal (or a future Runtime).
    def emit(command)
      @commands << command
      self
    end

    # Drain and clear any commands.
    def drain_commands
      cmds = @commands
      @commands = []
      cmds
    end

    # Primary hook: update the session based on an Event.
    #
    # Implementations should return one of:
    # - :handled    (event consumed)
    # - :unhandled  (not for this session)
    # - a Symbol action name (optional convenience)
    #
    # The base class provides a small helper for the common case where the
    # runtime already resolved an action.
    def update(_event, terminal:)
      raise NotImplementedError, "#{self.class} must implement #update"
    end

    # Convenience: perform a named action using the ActionContext.
    def call_action(action, ctx, *args)
      Actions.call(action, ctx, *args)
      :handled
    rescue ActionError
      :unhandled
    end

    # Allow runtime to attach additional views.
    def add_view(view)
      @views << view
      self
    end
  end
end
