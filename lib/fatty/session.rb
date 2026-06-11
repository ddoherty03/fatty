# frozen_string_literal: true

module Fatty
  # Base class for stateful runtime components.
  #
  # Charm/Bubbletea-style contract:
  #
  #   init(terminal:)               => commands
  #   update(message)               => commands
  #   view(screen:, renderer:, terminal:) => renders only (no return contract)
  #
  # Where `commands` is an Array (possibly empty). Terminal is responsible for
  # executing commands after each update cycle.
  class Session
    include Actionable

    attr_reader :id, :terminal, :keymap, :counter

    def initialize(id: nil, keymap: nil)
      @id = id || default_id
      @keymap = keymap
      @counter = Counter.new
    end

    # Called once when the session becomes active (e.g. pushed).
    # Subclasses may override to kick off timers/async work, etc.
    def init(terminal:)
      @terminal = terminal
      []
    end

    # Handle an incoming Command, which can carry an action or a KeyEvent.  On
    # execution, those can return one or more Commands, which update returns
    # to its caller for further dispatch.
    def update(command)
      # raise NotImplementedError, "#{self.class} must implement \#update"
    end

    # By default, does nothing.  Subclasses can override, but should not
    # mutate state here.
    def view
    end

    def close
    end

    # Save any state we want saved on quit, error, etc.
    def persist!
    end

    def tick
      false
    end

    private

    def log_update(command)
      payload = command.payload
      msg =
        case command.action
        when :key
          "#{self.class}#update(command -> #{command.inspect}) key: #{payload[:event]}"
        else
          sess_str =
            if command.target == :focused_session
              Terminal.find(:focused_session).to_s
            else
              command.target.to_s
            end
          "#{self.class}#update(command -> #{command.inspect}) session: #{sess_str}"
        end
      Fatty.debug(msg, tag: :session)
    end

    def normalize_action_result(result)
      case result
      when nil
        []
      when Command
        [result]
      when Array
        result.grep(Command)
      else
        []
      end
    end

    def alert_cmd(level, text, ev: nil)
      details =
        if ev
          {
            key: ev.key,
            ctrl: ev.respond_to?(:ctrl?) ? ev.ctrl? : ev.ctrl,
            meta: ev.respond_to?(:meta?) ? ev.meta? : ev.meta,
            shift: ev.respond_to?(:shift?) ? ev.shift? : ev.shift,
            text: ev.text
          }
        else
          {}
        end
      alert = Alert.new(text: text, level: level, details: details)
      Command.session(:alert, :show, alert: alert)
    end

    def default_id
      self.class.name
        .delete_prefix("Fatty::")
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
        .then { |name| :"#{name}_#{object_id}" }
    end

    def renderer
      terminal.renderer
    end

    def screen
      terminal.screen
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
    def apply_action(_action, _args, event:)
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
  end
end

require_relative "session/alert_session"
require_relative "session/status_session"
require_relative "session/modal_session"
require_relative "session/popup_session"
require_relative "session/search_session"
require_relative "session/isearch_session"
require_relative "session/output_session"
require_relative "session/shell_session"
require_relative 'session/prompt_session'
require_relative 'session/keytest_session'
