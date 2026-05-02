# frozen_string_literal: true

module Fatty
  module Themes
    class ResolveError < StandardError; end
    class MissingThemeError < ResolveError; end
    class InheritanceCycleError < ResolveError; end

    module Resolver
      ROLE_PARENTS = {
        input: :output,
        input_suggestion: :input,

        region: :output,
        cursor: :input,

        popup: :output,
        popup_frame: :popup,
        popup_input: :popup,
        popup_selection: :popup,
        popup_counts: :popup,

        search_input: :popup,

        match_current: :region,
        match_other: :region,

        pager_status: :output,

        info: :output,
        good: :info,
        warn: :info,
        error: :warn,
      }.freeze

      def self.empty_theme
        {
          name: nil,
          inherit: nil,
          roles: {},
          markdown: {},
          source: nil,
        }
      end

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
        merged[:roles] = resolve_role_inheritance(merged[:roles])
        merged[:name] = name
        merged[:inherit] = defn[:inherit]
        merged[:source] = defn[:source]

        resolved[name] = merged
      end

      def self.resolve_role_inheritance(roles)
        resolved = {}
        roles.each_key do |name|
          resolve_role(name, roles, resolved, stack: [])
        end
        resolved
      end

      def self.resolve_role(name, roles, resolved, stack:)
        return resolved[name] if resolved.key?(name)

        if stack.include?(name)
          raise InheritanceCycleError, "Role inheritance cycle: #{(stack + [name]).join(' -> ')}"
        end

        spec = roles[name] || {}

        parent_name =
          if spec.key?(:inherit)
            spec[:inherit]&.to_sym
          else
            ROLE_PARENTS[name]
          end

        parent_spec =
          if parent_name
            resolve_role(parent_name, roles, resolved, stack: stack + [name])
          else
            {}
          end

        resolved[name] = deep_merge_hash(parent_spec, spec.reject { |k, _| k == :inherit })
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
