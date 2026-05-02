# frozen_string_literal: true

require "yaml"

module Fatty
  module Themes
    module Loader
      RESERVED_KEYS = %i[name inherit markdown].freeze

      ROLE_ALIASES = {
        status_good: :good,
        status_info: :info,
        status_warn: :warn,
        status_error: :error,

        search: :search_input,
        search_highlight: :match_current,
        search_highlight_secondary: :match_other,
      }.freeze

      def self.load_dir(path, registry:)
        Dir.glob(File.join(path.to_s, "*.{yml,yaml}")).sort.each do |file|
          load_file(file, registry: registry)
        end
        registry
      end

      def self.load_file(path, registry:)
        data = YAML.safe_load_file(
          path,
          permitted_classes: [Symbol],
          aliases: false,
          symbolize_names: true,
        )

        unless data.is_a?(Hash)
          registry.warnings << "Theme file did not contain a mapping: #{path}"
          return
        end

        registry.add(normalize(data), source: path)
      rescue Psych::Exception => e
        message = "Theme YAML error in #{path}: #{e.class}: #{e.message}"
        registry.warnings << message
        Fatty.warn(message, tag: :theme) if Fatty.respond_to?(:warn)
        nil
      rescue StandardError => e
        message = "Theme load error in #{path}: #{e.class}: #{e.message}"
        registry.warnings << message
        Fatty.warn(message, tag: :theme) if Fatty.respond_to?(:warn)
        nil
      end

      def self.normalize(data)
        out = {
          name: normalize_optional_symbol(data[:name]),
          inherit: normalize_optional_symbol(data[:inherit]),
          roles: {},
          markdown: normalize_markdown(data[:markdown]),
        }

        data.each do |key, value|
          k = key.to_sym
          next if RESERVED_KEYS.include?(k)

          out[:roles][normalize_role_name(k)] = normalize_spec(value)
        end
        out
      end

      def self.normalize_role_name(name)
        sym = name.to_sym
        ROLE_ALIASES.fetch(sym, sym)
      end

      def self.normalize_markdown(value)
        return {} unless value.is_a?(Hash)

        value.each_with_object({}) do |(k, v), h|
          h[k.to_sym] = normalize_spec(v)
        end
      end

      def self.normalize_spec(value)
        return {} unless value.is_a?(Hash)

        value.each_with_object({}) do |(k, v), h|
          key = k.to_sym
          h[key] =
            case key
            when :attrs
              Array(v).map { |attr| attr.to_sym }
            when :border, :corners
              normalize_optional_symbol(v)
            else
              v
            end
        end
      end

      def self.normalize_optional_symbol(value)
        return if value.nil?

        text = value.to_s.strip
        return if text.empty?

        case text.downcase
        when "null", "nil", "none"
          nil
        else
          text.to_sym
        end
      end

    end
  end
end
