# frozen_string_literal: true

module Fatty
  # The MouseEvent class is a simple class to store a mouse event with its
  # modifiers.
  class MouseEvent
    attr_reader :button, :x, :y, :ctrl, :meta, :shift, :raw

    def initialize(button:, x: 0, y: 0, raw: nil, ctrl: false, meta: false, shift: false)
      @button = button
      @x = x
      @y = y
      @raw = raw
      @ctrl = ctrl
      @meta = meta
      @shift = shift
      Fatty.debug("#{self.class}#new(#{self})", tag: :event)
    end

    def key
      :mouse
    end

    def to_s
      self.class.button_to_str(button:, ctrl:, meta:, shift:)
    end

    def self.button_to_str(button:, ctrl: false, meta: false, shift: false)
      mods = []
      mods << "C" if ctrl
      mods << "M" if meta
      mods << "S" if shift
      button_str = button.to_s
      mods.empty? ? button_str : "#{mods.join('-')}-#{button_str}"
    end

    def printable?
      false
    end

    def mouse?
      true
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

    def bindings
      Fatty::KeyMap.active.bindings_for(self) || {}
    end

    def report
      rule = "=" * 55 + "\n"
      out = +""
      out << rule
      out << "Mouse report #{status_string}:\n"
      out << "  raw:       #{raw.inspect}\n"
      out << "  button:    #{button.inspect}\n"
      out << "  name:      #{to_s}\n"
      out << "  x:         #{x.inspect}\n"
      out << "  y:         #{y.inspect}\n"
      out << "  modifiers: #{modifier_text}\n"
      out << "  bindings:\n#{bindings_text}\n"
      out << "\n"
    end

    def suggested_snippet(_terminal_name)
      bindings.empty? ? suggested_mouse_binding : ""
    end

    private

    def status_string
      bindings.empty? ? "(UNBOUND)" : "(BOUND)"
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

      bindings.map { |context, binding|
        action, _args = binding_action(binding)
        "    context: #{context}: #{binding_text(binding)}#{action_target_text(action)}"
      }.join("\n")
    end

    def binding_action(binding)
      case binding
      when Array
        [binding[0], binding[1..] || []]
      else
        [binding, []]
      end
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

    def action_target_text(action)
      return "" unless action

      defn = Fatty::Actions.lookup(action)
      return "  (unregistered action)" unless defn

      "  (#{defn[:on]}: #{action_owner_name(defn[:owner])}##{defn[:method]})"
    end

    def action_owner_name(owner)
      name =
        if owner.respond_to?(:name) && owner.name
          owner.name
        else
          owner.to_s
        end
      name.split("::").last
    end

    def suggested_mouse_binding
      out = <<~TEXT

        No action is bound to #{to_s}.

        Suggested keybindings.yml entry:

        ............>8 snip here 8<....................
        #{yaml_desc}
        ............>8 snip here 8<....................
      TEXT

      out << <<~TEXT

      TEXT
      out
    end

    def yaml_desc
      lines = ["# #{to_s}", "- button: #{button}"]
      lines << "  shift: true" if shift?
      lines << "  ctrl: true" if ctrl?
      lines << "  meta: true" if meta?
      lines << "  context: <valid_context>"
      lines << "  action: <action_name>"
      lines.join("\n")
    end
  end
end
