# frozen_string_literal: true

module Fatty
  module Help
    def self.path
      File.expand_path("../../help/help.md", __dir__)
    end

    def self.text
      File.read(path)
    end
  end
end
