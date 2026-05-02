# frozen_string_literal: true

module Fatty
  module Themes
    module Manager
      FALLBACK_THEME = :mono

      def self.registry
        @registry ||=
          begin
            reg = Registry.new
            Loader.load_dir(Fatty::Config.user_themes_dir, registry: reg)
            reg
          end
      end

      def self.load!
        registry.clear
        Loader.load_dir(Fatty::Config.user_themes_dir, registry: registry)
        registry
      end

      def self.theme_names
        registry.names.sort
      end

      def self.current
        @current ||= :wordperfect
      end

      def self.set(theme)
        t = theme.to_sym
        @current = theme_names.include?(t) ? t : FALLBACK_THEME
      end

      def self.cycle
        names = theme_names
        return set(FALLBACK_THEME) if names.empty?

        idx = names.index(current) || 0
        set(names[(idx + 1) % names.length])
      end

      def self.fetch(name)
        Resolver.resolve(registry, name)
      end

      def self.roles(name = current)
        fetch(name)[:roles]
      end

      def self.markdown(name = current)
        fetch(name)[:markdown]
      end
    end
  end
end
