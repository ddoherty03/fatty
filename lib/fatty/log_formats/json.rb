# frozen_string_literal: true

module Fatty
  module Logger
    class JsonFormatter < ::Logger::Formatter
      def call(level, time, progname, msg)
        rec = {
          t: time.utc.iso8601(6),
          sev: level,
          prog: progname
        }

        case msg
        when Hash
          rec.merge!(stringify_keys(msg))
        else
          merge_string_message!(rec, msg)
        end

        rec.to_json << "\n"
      end

      private

      def stringify_keys(hash)
        hash.each_with_object({}) do |(k, v), memo|
          memo[k.to_s] = v
        end
      end

      def merge_string_message!(rec, msg)
        text = msg.to_s

        begin
          parsed = JSON.parse(text)
          if parsed.is_a?(Hash)
            rec.merge!(parsed)
          else
            rec["msg"] = parsed
          end
        rescue JSON::ParserError
          rec["msg"] = text
        end
      end
    end
  end
end
