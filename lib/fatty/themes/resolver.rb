# frozen_string_literal: true

module Fatty
  module Themes
    class ResolveError < StandardError; end
    class MissingThemeError < ResolveError; end
    class InheritanceCycleError < ResolveError; end

    # The Resolver module is responsible for transforming a raw theme loaded
    # by the Loader into a fully-resolved "theme_spec".
    #
    # Resolution includes:
    # - applying inheritance between themes
    # - applying inheritance between roles
    # - filling in default attributes
    # - synthesizing "composite" roles used by the alert panel
    #
    # Composite alert roles (e.g., :alert_info, :alert_warn, etc.) combine the
    # background and structural properties of the :alert role with the foreground
    # and attributes of the semantic roles (:good, :info, :warn, :error).
    #
    # The result of resolution is a Hash keyed by role names, where each value
    # is a symbolic color specification (typically using color names and attrs).
    # We refer to this Hash as a "theme_spec".
    #
    # A theme_spec is not directly renderable. Before rendering, it must be
    # "compiled" into a palette by Fatty::Colors::Palette.apply!. The palette
    # maps each role to concrete rendering data (RGB values for truecolor or
    # Curses color pairs, along with attributes).
    #
    # Renderer classes consume only the compiled palette and never operate
    # directly on the theme_spec.
    # module Resolver
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
        raw[:roles] = add_composite_roles(raw[:roles])
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

      def self.add_composite_roles(roles)
        roles = roles.dup

        roles[:alert_info]  = composite_role(roles[:alert] || {}, roles[:info]  || {})
        roles[:alert_good]  = composite_role(roles[:alert] || {}, roles[:good]  || {})
        roles[:alert_warn]  = composite_role(roles[:alert] || {}, roles[:warn]  || {})
        roles[:alert_error] = composite_role(roles[:alert] || {}, roles[:error] || {})
        roles
      end
      private_class_method :add_composite_roles

      def self.composite_role(base, accent)
        {
          fg: accent[:fg] || accent["fg"] || base[:fg] || base["fg"],
          bg: base[:bg] || base["bg"] || accent[:bg] || accent["bg"],
          attrs: accent[:attrs] || accent["attrs"] || base[:attrs] || base["attrs"],
        }.compact
      end
      private_class_method :composite_role
    end
  end
end
