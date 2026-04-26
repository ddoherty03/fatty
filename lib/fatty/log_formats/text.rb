# frozen_string_literal: true

#       def render_hash(msg)
#         event = msg[:event] || msg["event"]
#         tag = msg[:tag] || msg["tag"]

#         extras =
#           msg.reject do |k, _|
#           k.to_s == "event" || k.to_s == "tag"
#         end

#         parts = []
#         parts << "[#{tag}]" if tag && !tag.to_s.empty?
#         parts << event.to_s if event

#         unless extras.empty?
#           parts << "\n" + PP.pp(extras, +"").rstrip
#         end

#         parts.join(" ")
#       end
#     end
#   end
# end

module FatTerm
  module Logger
    class TextFormatter < ::Logger::Formatter
      def call(level, time, progname, msg)
        ts = time.utc.iso8601(6)

        body =
          case msg
          when Hash
            render_hash(msg)
          else
            msg.to_s
          end

        "#{ts} #{level} #{progname} #{body}\n"
      end

      private

      def render_hash(msg)
        event = msg[:event] || msg["event"]
        tag = msg[:tag] || msg["tag"]

        extras =
          msg.reject do |k, _|
          k.to_s == "event" || k.to_s == "tag"
        end

        parts = []
        parts << "[#{tag}]" if tag && !tag.to_s.empty?
        parts << event.to_s if event

        unless extras.empty?
          rendered = PP.pp(extras, +"").rstrip
          parts << "\n#{rendered}"
        end

        parts.join(" ")
      end
    end
  end
end
