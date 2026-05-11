# frozen_string_literal: true

module Fatty
  module Themes
    class ResolveError < StandardError; end
    class MissingThemeError < ResolveError; end
    class InheritanceCycleError < ResolveError; end

    module Resolver
      DEFAULT_ROLE_SPECS = {
        region: { attrs: [:reverse] },
        cursor: { attrs: [:reverse] },
        input_suggestion: { attrs: [:dim] },
        pager_status: { attrs: [:reverse] },
        search_input: { attrs: [:reverse] },
        match_current: { attrs: [:reverse] },
        match_other: { attrs: [:underline] },
        popup_counts: { attrs: [:bold] },
        alert: { attrs: [:bold] },
      }.freeze

      ROLE_PARENTS = {
        input: :output,
        input_suggestion: :input,

        region: :output,
        cursor: :input,

        popup: :output,
        popup_frame: :popup,
        popup_input: :input,
        popup_selection: :region,
        popup_counts: :popup,

        search_input: :popup,

        match_current: :region,
        match_other: :region,

        status: :output,
        alert: :output,
        info: :output,
        good: :info,
        warn: :info,
        error: :warn,

        pager_status: :status,
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
        raw = merge_theme_chain(registry, name.to_sym, stack: [])
        raw[:roles] = resolve_role_inheritance(raw[:roles])
        raw[:name] = name.to_sym
        raw
      end

      def self.merge_theme_chain(registry, name, stack:)
        defn = registry.fetch(name)
        raise MissingThemeError, "Theme not found: #{name}" unless defn

        if stack.include?(name)
          cycle = (stack + [name]).join(" -> ")
          raise InheritanceCycleError, "Theme inheritance cycle: #{cycle}"
        end

        parent =
          if defn[:inherit]
            merge_theme_chain(registry, defn[:inherit], stack: stack + [name])
          else
            empty_theme
          end

        merged = deep_merge(parent, defn)
        merged[:name] = name
        merged[:inherit] = defn[:inherit]
        merged[:source] = defn[:source]
        merged
      end

      def self.resolve_role_inheritance(roles)
        resolved = {}
        names = (
          ROLE_PARENTS.keys +
          ROLE_PARENTS.values +
          DEFAULT_ROLE_SPECS.keys +
          roles.keys
        ).compact.uniq

        names.each do |name|
          resolve_role(name, roles, resolved, stack: [])
        end

        resolved
      end

      def self.resolve_role(name, roles, resolved, stack:)
        return resolved[name] if resolved.key?(name)

        if stack.include?(name)
          raise InheritanceCycleError, "Role inheritance cycle: #{(stack + [name]).join(' -> ')}"
        end

        spec = roles[name] || DEFAULT_ROLE_SPECS.fetch(name, {})
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
