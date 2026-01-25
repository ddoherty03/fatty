# frozen_string_literal: true

module FatTerm
  module Actions
    @defs = {} # { Symbol => { owner:, on:, doc:, method: } }

    def self.reset!
      @defs.clear
    end

    def self.lookup(name)
      @defs[name.to_sym]
    end

    class << self
      def register(name, owner:, on:, method_name: name, doc: nil)
        key = name.to_sym
        raise ArgumentError, "action already registered: #{key}" if @defs.key?(key)

        @defs[key] = {
          owner: owner,
          on: on.to_sym,
          doc: doc,
          method: method_name.to_sym
        }
      end

      def call(name, ctx, *args)
        key = name.to_sym
        defn = @defs[key] or raise ArgumentError, "Unknown action: #{key}"

        target = ctx.public_send(defn[:on])
        raise ArgumentError, "ctx.#{defn[:on]} is nil for action #{key}" unless target

        target.public_send(defn[:method], *args)
      end

      def registered?(name) = @defs.key?(name.to_sym)
    end
  end

  # Runtime wiring; expand as needed.
  ActionContext = Struct.new(:buffer, :field, :terminal, :pager, keyword_init: true)

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
        else
          # If this is an alias (action name differs from method), define the alias method
          if name != to && !instance_methods.include?(name)
            # Prefer a real alias if the target method already exists; otherwise define a delegator.
            if instance_methods.include?(to)
              alias_method name, to
            else
              define_method(name) { |*args, &blk| public_send(to, *args, &blk) }
            end
          end
        end

        FatTerm::Actions.register(name, owner: self, on: on, method_name: to, doc: doc)
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
