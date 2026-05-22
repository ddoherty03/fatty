# frozen_string_literal: true

module Fatty
  module Markdown
    def self.render(text, width: 80, palette: nil)
      markdown = Redcarpet::Markdown.new(
        Fatty::AnsiRenderer.new(width: width, palette: palette),
        no_intra_emphasis: true,
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
