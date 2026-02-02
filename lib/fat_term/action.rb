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
      key = name.to_sym
      raise ActionError, "action already registered: #{key}" if @defs.key?(key)

      @defs[key] = {
        owner: owner,
        on: on.to_sym,
        doc: doc,
        method: method_name.to_sym
      }
    end

    def self.call(name, ctx, *args, **kwargs)
      key = name.to_sym
      defn = @defs[key] or raise ActionError, "Unknown action: #{key}"

      target = ctx.public_send(defn[:on])
      raise ActionError, "ctx.#{defn[:on]} is nil for action #{key}" unless target

      target.public_send(defn[:method], *args, **kwargs)
    end

    def self.registered?(name)
      @defs.key?(name.to_sym)
    end
  end

  # Runtime wiring; expand as needed.
  ActionContext = Struct.new(:buffer, :field, :terminal, :pager, keyword_init: true)
end
