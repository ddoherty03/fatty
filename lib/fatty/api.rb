module Fatty
  module ChooseApi
    # simplecov:disable

    private

    def normalize_choices(choices)
      case choices
      when Hash
        choices.map do |label, value|
          [label.to_s, value]
        end
      when Array
        choices.map do |choice|
          unless choice.is_a?(String)
            raise ArgumentError, "choices array must contain strings"
          end

          [choice, choice]
        end
      else
        raise ArgumentError, "choices must be an Array of strings or a Hash"
      end
    end
  end
end

# simplecov:enable

require_relative './api/output.rb'
require_relative './api/status.rb'
require_relative './api/alert.rb'
require_relative './api/choose.rb'
require_relative './api/prompt.rb'
require_relative './api/progress.rb'
require_relative './api/menu.rb'
require_relative './api/keytest.rb'
require_relative './api/environment.rb'
