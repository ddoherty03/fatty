# frozen_string_literal: true

module Fatty
  module Markdown
    def self.render(text, width: 80, palette: nil, theme: nil, truecolor: false) #
      markdown = Redcarpet::Markdown.new(
        Fatty::AnsiRenderer.new(width: width, palette: palette, theme: theme, truecolor: truecolor),
        tables: true,
        fenced_code_blocks: true,
        autolink: true,
        disable_indented_code_blocks: true,
        strikethrough: true,
        space_after_headers: true,
        underline: true,
        highlight: true,
        footnotes: true,
      )
      markdown.render(text)
    end
  end
end
