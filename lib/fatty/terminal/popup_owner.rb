# frozen_string_literal: true

module Fatty
  class Terminal
    class PopupOwner
      attr_reader :on_result, :on_cancel, :on_change

      def initialize(on_result: nil, on_cancel: nil, on_change: nil)
        @on_result = on_result
        @on_cancel = on_cancel
        @on_change = on_change
      end

      def update(command)
        result =
          case command.action
          when :popup_result, :prompt_result
            on_result&.call(command.payload)
          when :popup_cancelled, :prompt_cancelled
            on_cancel&.call
          when :popup_changed
            on_change&.call(command.payload)
          end

        Command.normalize_list(result)
      end
    end
  end
end
