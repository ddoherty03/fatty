module Fatty
  module Actionable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Optional override; by default infer slot from class name (InputBuffer -> :buffer)
      def action_on(sym = nil)
        @default_action_target = sym&.to_sym
      end

      def default_action_target
        @default_action_target || infer_action_target
      end

      def desc(text)
        @__next_action_doc = text.to_s
      end

      def next_action_doc
        doc = @__next_action_doc
        @__next_action_doc = nil
        doc
      end

      # Define instance method AND register as bindable action.
      #
      # Examples:
      #   action :bol { @cursor = 0 }
      #   action :insert { |str| ... }
      #   action :backward_char, to: :move_left  # alias action name to a method
      #
      def action(name, on: default_action_target, to: name, doc: nil, &block)
        name = name.to_sym
        on   = on.to_sym
        to   = to.to_sym

        # Prefer desc() if present, else doc: kwarg
        doc ||= next_action_doc

        if block
          # define the underlying method (usually same as name)
          define_method(to, &block)
        elsif name != to && !method_defined?(name)
          # If this is an alias (action name differs from method), define the alias method

          # Prefer a real alias if the target method already exists; otherwise define a delegator.
          if method_defined?(to)
            alias_method name, to
          else
            define_method(name) { |*args, &blk| public_send(to, *args, &blk) }
          end
        end
        Fatty::Actions.register(name, owner: self, on: on, method_name: to, doc: doc)
      end

      private

      def infer_action_target
        base = name.split("::").last
        return :buffer   if base == "InputBuffer"
        return :field    if base == "InputField"
        return :terminal if base == "Terminal"
        return :pager    if base == "Pager"

        base.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
      end
    end
  end
end
