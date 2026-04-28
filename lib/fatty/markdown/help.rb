# lib/fatty/help.rb
# frozen_string_literal: true

require "redcarpet"
require_relative "ansi_renderer"

module Fatty
  module Help
    def self.path
      File.expand_path("help.md", __dir__)
    end

    def self.render(width: 80)
      renderer = Fatty::AnsiRenderer.new(width: width)
      markdown = Redcarpet::Markdown.new(
        renderer,
        tables: true,
        fenced_code_blocks: true,
        autolink: true,
      )
      markdown.render(text)
    end

    def self.text
      File.read(path)
    end
  end
end
