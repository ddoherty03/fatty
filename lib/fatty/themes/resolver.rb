# frozen_string_literal: true

module Fatty
  module Themes
    class ResolveError < StandardError; end
    class MissingThemeError < ResolveError; end
    class InheritanceCycleError < ResolveError; end

    module Resolver
      def self.resolve(registry, name)
        resolved = {}
        resolve_one(registry, name.to_sym, resolved: resolved, stack: [])
      end

      def self.resolve_one(registry, name, resolved:, stack:)
        return resolved[name] if resolved.key?(name)

        defn = registry.fetch(name)
        raise MissingThemeError, "Theme not found: #{name}" unless defn

        if stack.include?(name)
          cycle = (stack + [name]).join(" -> ")
          raise InheritanceCycleError, "Theme inheritance cycle: #{cycle}"
        end

        parent =
          if defn[:inherit]
            resolve_one(registry, defn[:inherit], resolved: resolved, stack: stack + [name])
          else
            empty_theme
          end

        merged = deep_merge(parent, defn)
        merged[:name] = name
        merged[:inherit] = defn[:inherit]
        merged[:source] = defn[:source]

        resolved[name] = merged
      end

      def self.empty_theme
        {
          name: nil,
          inherit: nil,
          roles: {},
          markdown: {},
          source: nil,
        }
      end

      def self.deep_merge(parent, child)
        out = parent.dup

        out[:roles] = deep_merge_hash(parent[:roles] || {}, child[:roles] || {})
        out[:markdown] = deep_merge_hash(parent[:markdown] || {}, child[:markdown] || {})

        child.each do |key, value|
          next if [:roles, :markdown].include?(key)

          out[key] = value
        end

        out
      end

      def self.deep_merge_hash(parent, child)
        parent.merge(child) do |_key, old_value, new_value|
          if old_value.is_a?(Hash) && new_value.is_a?(Hash)
            deep_merge_hash(old_value, new_value)
          else
            new_value
          end
        end
      end
    end
  end
end
