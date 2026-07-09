# frozen_string_literal: true

module Fatty
  module CoreExt
    module Hash
      refine ::Hash do
        def deep_merge(other)
          merge(other) do |_key, old_value, new_value|
            if old_value.is_a?(::Hash) && new_value.is_a?(::Hash)
              old_value.deep_merge(new_value)
            else
              new_value
            end
          end
        end
      end
    end
  end
end
