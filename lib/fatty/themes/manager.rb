# frozen_string_literal: true

module Fatty
  module Themes
    module Manager
      attr_reader :warning

      FALLBACK_THEME = :terminal

      def self.warning
        @warning
      end

      def self.registry
        @registry ||=
          begin
            reg = Registry.new
            Loader.load_dir(Fatty::Config.user_themes_dir, registry: reg)
            Loader.load_dir(Fatty::Config.app_themes_dir, registry: reg) if Fatty::Config.app_themes_dir
            reg
          end
      end

      def self.load!
        @warning = nil
        registry.clear
        Loader.load_dir(Fatty::Config.user_themes_dir, registry: registry)
        Loader.load_dir(Fatty::Config.app_themes_dir, registry: registry) if Fatty::Config.app_themes_dir
        registry
      end

      def self.theme_names
        registry.names.sort
      end

      def self.current
        return @current if @current

        theme = Fatty::Config.config[:theme]
        @current =
          if theme && !theme.to_s.strip.empty?
            set(theme)
          else
            FALLBACK_THEME
          end
      end

      def self.set(theme)
        return current unless theme

        t = theme.to_sym

        if theme_names.include?(t)
          @warning = nil
          @current = t
          Fatty::Config.set_preference(:theme, t)
          @current
        else
          @warning = "Unknown theme in config: '#{theme}'; using '#{FALLBACK_THEME}'"
          Fatty.warn(@warning, tag: :theme)
          @current = FALLBACK_THEME
        end
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
