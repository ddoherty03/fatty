# frozen_string_literal: true

module Fatty
  module Colors
    module ThemeManager
      def self.theme_names
        # Stable order: prefer a deterministic order instead of hash iteration.
        @theme_names ||= Themes.names.map(&:to_sym).sort
      end

      def self.current
        @current ||= :wordperfect
      end

      def self.set(theme)
        t = theme.to_sym
        @current = theme_names.include?(t) ? t : :wordperfect
      end

      def self.cycle
        names = theme_names
        return set(:wordperfect) if names.empty?

        idx = names.index(current) || 0
        set(names[(idx + 1) % names.length])
      end
    end
  end
end
