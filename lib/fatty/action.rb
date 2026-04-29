# frozen_string_literal: true

module Fatty
  class ActionError < StandardError; end

  module Actions
    @defs = {} # { Symbol => { owner:, on:, doc:, method: } }

    def self.names
      @defs.keys.sort
    end

    def self.valid_names
      names.map(&:to_s)
    end

    def self.catalog
      names.map do |name|
        defn = @defs[name]
        {
          name: name.to_s,
          doc: defn[:doc],
          on: defn[:on].to_s,
          method: defn[:method].to_s,
        }
      end
    end

    def self.catalog_by_target
      @defs
        .group_by { |_name, defn| defn[:on].to_s }
        .sort
        .to_h do |target, entries|
          names = entries.map { |name, _defn| name.to_s }.sort
          [target, names]
        end
    end

    def self.snapshot
      @defs.dup
    end

    def self.restore(snapshot)
      @defs = snapshot
    end

    def self.reset!
      @defs.clear
    end

    def self.defs
      @defs
    end

    def self.lookup(name)
      @defs[name.to_sym]
    end

    def self.register(name, owner:, on:, method_name: name, doc: nil)
      arg_str = "Action.register: name: #{name}, on: #{on}, method_name: #{method_name}, doc: #{doc}"
      Fatty.debug("Action.register(#{arg_str})", tag: :action)
      key = name.to_sym
      raise ActionError, "action already registered for #{key}" if @defs.key?(key)

      @defs[key] = {
        owner: owner,
        on: on.to_sym,
        doc: doc,
        method: method_name.to_sym,
      }
    end

    def self.call(name, env, *args, **kwargs)
      arg_str = "name: #{name}, env: #{env}, args: #{args}, kwargs: #{kwargs}"
      Fatty.debug("Action.call(#{arg_str})", tag: :action)
      key = name.to_sym
      defn = @defs[key] or raise ActionError, "Unknown action: #{key}"

      target = env.public_send(defn[:on])
      raise ActionError, "env.#{defn[:on]} is nil for action #{key}" unless target

      # Inject count: from env.counter when the target accepts it.
      if env.counter && env.counter.active? && !kwargs.key?(:count)
        meth = target.method(defn[:method])
        params = meth.parameters

        accepts_count =
          params.any? { |(kind, pname)| kind == :key && pname == :count } ||
          params.any? { |(kind, _pname)| kind == :keyrest }

        if accepts_count
          kwargs = kwargs.merge(count: env.counter.consume(default: 1))
        end
      end

      target.public_send(defn[:method], *args, **kwargs)
    end

    def self.registered?(name)
      @defs.key?(name.to_sym)
    end
  end
end
