# frozen_string_literal: true

module FatTerm
  # Base class for stateful runtime components.
  #
  # Charm/Bubbletea-style contract:
  #
  #   init(terminal:)               => commands
  #   update(message, terminal:)    => commands
  #   view(screen:, renderer:, terminal:) => renders only (no return contract)
  #
  # Where `commands` is an Array (possibly empty). Terminal is responsible for
  # executing commands after each update cycle.
  class Session
    include Actionable

    attr_reader :views, :keymap, :counter

    def initialize(keymap: nil, views: [])
      @keymap = keymap
      @views = Array(views)
      @counter = Counter.new
    end

    def inspect
      "#{self.class.name}:#{object_id}"
    end

    def add_view(view)
      @views << view
      view
    end

    # Called once when the session becomes active (e.g. pushed).
    # Subclasses may override to kick off timers/async work, etc.
    def init(terminal:)
      []
    end

    # Handle a message and return commands.
    def update(message, terminal:)
      FatTerm.log("#{self.class}#update(message -> #{message})", tag: :session)

      commands =
        case message[0]
        when :key
          ev = message[1]
          action, args = resolve_action(ev)

          FatTerm.log("#{self.class}.update: key ev=#{ev.inspect} action=#{action.inspect} args=#{args.inspect}", tag: :session)

          if action
            handle_action(action, args, terminal: terminal, event: ev)
          else
            update_key(ev, terminal: terminal)
          end
        when :cmd
          FatTerm.log("#{self.class}.update: cmd message=#{message.inspect}", tag: :session)
          update_cmd(message[1], message[2], terminal: terminal)
        else
          FatTerm.log("#{self.class}.update: unknown message[0]=#{message[0].inspect}", tag: :session)
          []
        end
      commands
    end

    # Save any state we want saved on quit, error, etc.
    def persist!(terminal:)
    end

    def tick(terminal:)
      false
    end

    def resolve_action(ev)
      return [nil, []] unless keymap

      keymap.resolve_action(ev, contexts: keymap_contexts)
    end

    # Subclasses can override to vary contexts dynamically
    # (paging/isearch/popup/etc).  Must return an Array of symbols in
    # precedence order.
    def keymap_contexts
      [:input]
    end

    # Subclasses override this to react to resolved actions.
    def handle_action(_action, _args, terminal:, event:)
      []
    end

    desc "Accumulate a count with a decimal digit"
    action :count_digit, on: :session do |n|
      counter.push_digit(n)
    end

    desc "Clear the accumulated count"
    action :count_clear, on: :session do
      counter.clear!
    end

    desc "Universal argument (C-u)"
    action :universal_argument, on: :session do
      counter.universal_argument!
    end

    # Render the session.
    #
    # By default, renders all views belonging to the session, ordered by z-index.
    # Subclasses can override, but should not mutate state here.
    def view(screen:, renderer:, terminal:)
      views.sort_by(&:z).each do |v|
        v.render(screen:, renderer:, terminal:, session: self)
      end
    end

    def close
      nil
    end

    def handle_resize(terminal:)
      []
    end

    private

    def update_key(_ev, terminal:)
      []
    end

    def update_cmd(_name, _payload, terminal:)
      []
    end
  end
end
