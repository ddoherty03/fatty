# frozen_string_literal: true

module Fatty
  module Themes
    class Registry
      attr_reader :warnings

      def initialize
        @defs = {}
        @warnings = []
      end

      def clear
        @defs.clear
        @warnings.clear
        nil
      end

      def add(defn, source: nil)
        name = normalize_name(defn[:name])
        if name
          @defs[name] = defn.merge(name: name, source: source)
        else
          warn("Theme missing name#{source_suffix(source)}")
        end
        nil
      end

      def names
        @defs.keys
      end

      def include?(name)
        @defs.key?(normalize_name(name))
      end

      def fetch(name)
        @defs[normalize_name(name)]
      end

      def each(&block)
        @defs.each_value(&block)
      end

      private

      def normalize_name(name)
        return nil if name.nil?

        text = name.to_s.strip
        text.empty? ? nil : text.to_sym
      end

      def warn(message)
        @warnings << message
        Fatty.warn(message, tag: :theme) if Fatty.respond_to?(:warn)
      end

      def source_suffix(source)
        source ? " in #{source}" : ""
      end
    end
  end
end
