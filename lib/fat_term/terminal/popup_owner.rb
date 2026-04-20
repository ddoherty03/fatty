  # frozen_string_literal: true

module FatTerm
  class Terminal
    class PopupOwner
      attr_reader :on_result, :on_cancel

      def initialize(on_result: nil, on_cancel: nil)
        @on_result = on_result
        @on_cancel = on_cancel
      end

      def update(msg, terminal:)
        _cmd, name, payload = msg

        case name
        when :popup_result, :prompt_result
          on_result&.call(payload)
        when :popup_cancelled, :prompt_cancelled
          on_cancel&.call
        end
        []
      end
    end
  end
end
