# frozen_string_literal: true

module FatTerm
  module Sessions
    # A pinned, non-interactive overlay session responsible for rendering alerts.
    #
    # It is intentionally dumb:
    #   - Terminal does not special-case alerts
    #   - other sessions emit commands like:
    #       [:send, :alert, :show, { level:, message: }]
    #       [:send, :alert, :clear, {}]
    class AlertSession < Session
      attr_reader :current

      def initialize
        super(views: [])
        @current = nil
      end

      def id
        :alert
      end

      def update(message, terminal:)
        if message.is_a?(Array) && message[0] == :cmd
          name, payload = message[1], (message[2] || {})

          case name
          when :show
            level = (payload[:level] || :info).to_sym
            text  = (payload[:message] || payload[:text]).to_s
            @current = FatTerm::Alert.new(level: level, message: text)
          when :clear
            @current = nil
          end
        end

        [self, []]
      end

      def view(screen:, renderer:, terminal:)
        renderer.render_alert(@current)
      end
    end
  end
end
