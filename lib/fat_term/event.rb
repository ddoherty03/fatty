# frozen_string_literal: true

module FatTerm
  class History
    class Entry
      attr_reader :text, :kind, :ctx, :stamp

      def initialize(text:, kind: :command, ctx: nil, stamp: nil)
        @text  = text.to_s
        @kind  = kind.to_sym
        @ctx   = normalize_ctx(ctx)
        @stamp = stamp || Time.now
      end

      def to_h
        {
          "text" => text,
          "kind" => kind.to_s,
          "ctx" => ctx,
          "stamp" => stamp.iso8601
        }
      end

      def command?
        kind == :command
      end

      def search?
        kind == :search_string || kind == :search_regex
      end

      def ctx_fetch(key, default = nil)
        ctx.fetch(key.to_s, default)
      end

      def self.from_h(hash)
        hash = hash.transform_keys(&:to_s)

        new(
          text:  hash.fetch("text", ""),
          kind:  hash.fetch("kind", "command"),
          ctx:   hash["ctx"],
          stamp: parse_stamp(hash["stamp"]),
        )
      end

      def self.parse_stamp(value)
        case value
        when Time
          value
        when String
          Time.iso8601(value)
        end
      rescue ArgumentError
        nil
      end

      private_class_method :parse_stamp

      private

      def normalize_ctx(value)
        return {} unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, val), out|
          out[key.to_s] = val
        end
      end
    end
  end
end
