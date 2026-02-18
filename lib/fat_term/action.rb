# frozen_string_literal: true

module FatTerm
  class ActionError < StandardError; end

  module Actions
    @defs = {} # { Symbol => { owner:, on:, doc:, method: } }

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
      FatTerm.log("Action.register(#{arg_str})", tag: :action)
      key = name.to_sym
      raise ActionError, "action already registered: #{key}" if @defs.key?(key)

      @defs[key] = {
        owner: owner,
        on: on.to_sym,
        doc: doc,
        method: method_name.to_sym
      }
    end

    def self.call(name, env, *args, **kwargs)
      arg_str = "name: #{name}, env: #{env}, args: #{args}, kwargs: #{kwargs}"
      FatTerm.log("Action.call(#{arg_str})", tag: :action)
      key = name.to_sym
      defn = @defs[key] or raise ActionError, "Unknown action: #{key}"

      target = env.public_send(defn[:on])
      raise ActionError, "env.#{defn[:on]} is nil for action #{key}" unless target

      target.public_send(defn[:method], *args, **kwargs)
    end

    def self.registered?(name)
      @defs.key?(name.to_sym)
    end
  end
end
