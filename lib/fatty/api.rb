module Fatty
  module ChooseApi
    private

    def normalize_choices(choices)
      Array(choices).map do |choice|
        if choice.is_a?(Array) && choice.length == 2
          [choice[0].to_s, choice[1]]
        else
          [choice.to_s, choice]
        end
      end
    end
  end
end

require_relative './api/output.rb'
require_relative './api/status.rb'
require_relative './api/alert.rb'
require_relative './api/choose.rb'
require_relative './api/prompt.rb'
require_relative './api/progress.rb'
require_relative './api/menu.rb'
require_relative './api/keytest.rb'
