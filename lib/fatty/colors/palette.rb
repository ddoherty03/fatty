# frozen_string_literal: true

module Fatty
  module Colors
    # Palette builds an "active" role->(fg,bg,pair) mapping by:
    # 1) taking a builtin theme (optional)
    # 2) deep-merging user overrides from config (optional)
    # 3) resolving each fg/bg via Fatty::Color.resolve
    # 4) initializing Curses color pairs (when apply! is used)
    #
    # It is safe to use without curses if you only call .build (e.g. in specs).
    module Palette
      DEFAULT_ROLE = { fg: "default", bg: "default" }.freeze

      # Build a merged role spec hash (no numeric resolution yet).
      #
      # cfg is expected like:
      #   { theme: "wordperfect", popup: { fg: "yellow", bg: "navy" }, ... }
      #
      # This method accepts either:
      # - the whole config hash (Fatty::Config.config), OR
      # - the ui.color subtree directly
      def build_spec(cfg)
        color_cfg = extract_color_cfg(cfg)

        theme_name = color_cfg[:theme] || color_cfg["theme"] || Fatty::Themes::Manager.current
        theme_roles = Fatty::Themes::Manager.roles(theme_name)

        merged = {}
        merged = deep_merge(merged, theme_roles) if theme_roles
        merged = deep_merge(merged, color_cfg_without_theme(color_cfg))

        merged
      end

      # Build resolved palette (no curses required).
      #
      # Returns:
      #   { role_sym => { fg: <idx>, bg: <idx>, pair: <pair_id> }, ... }
      def build(cfg, available_colors:)
        spec = build_spec(cfg)
        out = {}

        Pairs::ROLE_TO_PAIR.each do |role, pair_id|
          role_spec = spec.fetch(role, DEFAULT_ROLE)

          fg_spec = role_spec[:fg] || role_spec["fg"] || DEFAULT_ROLE[:fg]
          bg_spec = role_spec[:bg] || role_spec["bg"] || DEFAULT_ROLE[:bg]

          fg = Fatty::Color.resolve(fg_spec, available_colors: available_colors)
          bg = Fatty::Color.resolve(bg_spec, available_colors: available_colors)
          attrs = Array(role_spec[:attrs] || role_spec["attrs"]).map(&:to_sym)

          out[role] = { fg: fg, bg: bg, pair: pair_id, attrs: attrs }
        end

        out
      end

      # Initialize curses pairs and return the resolved palette.
      def apply!(cfg, available_colors:)
        palette = build(cfg, available_colors: available_colors)

        return palette unless ::Curses.has_colors?

        ::Curses.start_color
        ::Curses.use_default_colors if ::Curses.respond_to?(:use_default_colors)

        palette.each_value do |entry|
          ::Curses.init_pair(entry[:pair], entry[:fg], entry[:bg])
        end

        palette
      end

      # Helpers
      def extract_color_cfg(cfg)
        return {} if cfg.nil?

        # Accept passing either Fatty::Config.config or ui.color subtree.
        ui = cfg[:ui] || cfg["ui"]
        color = ui && (ui[:color] || ui["color"])
        return color if color

        # maybe already the color subtree
        if cfg.key?(:theme) || cfg.key?("theme") || cfg.key?(:popup) || cfg.key?("popup")
          cfg
        else
          {}
        end
      end

      def color_cfg_without_theme(color_cfg)
        h = {}
        color_cfg.each do |k, v|
          next if k.to_sym == :theme

          role = Fatty::Themes::Loader.normalize_role_name(k)
          h[role] = v
        end
        h
      end

      # Deep merge for: role => { fg:, bg: }
      # Later keys override earlier keys.
      def deep_merge(a, b)
        out = (a || {}).dup
        (b || {}).each do |k, v|
          ks = k.to_sym
          out[ks] =
            if out[ks].is_a?(Hash) && v.is_a?(Hash)
              out[ks].merge(v)
            else
              v
            end
        end
        out
      end

      module_function(
        :build_spec,
        :build,
        :apply!,
        :extract_color_cfg,
        :color_cfg_without_theme,
        :deep_merge,
      )
    end
  end
end
