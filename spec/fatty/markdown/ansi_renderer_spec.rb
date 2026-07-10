# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe AnsiRenderer do
    describe "#autolink" do
      it "emits dim for markdown URL roles with dim attrs" do
        renderer = AnsiRenderer.new(
          width: 80,
          palette: {
            markdown_link: {
              attrs: [:underline],
              fg_rgb: [255, 255, 255],
              bg_rgb: nil,
            },
          },
        )

        rendered = renderer.autolink("https://example.com", nil)

        expect(rendered).to include("\e[4")
      end
    end

    describe "#link" do
      it "emits dim for the URL portion" do
        renderer = AnsiRenderer.new(
          width: 80,
          palette: {
            markdown_link: {
              attrs: [:underline],
              fg_rgb: [255, 255, 255],
              bg_rgb: nil,
            },
            markdown_url: {
              attrs: [:dim],
              fg_rgb: [128, 128, 128],
              bg_rgb: nil,
            },
          },
        )

        rendered = renderer.link("https://example.com", nil, "example")

        expect(rendered).to include("example")
        expect(rendered).to include("<https://example.com>")
        expect(rendered).to include("\e[4")
        expect(rendered).to include("\e[2")
      end
    end

    describe "default colors" do
      it "does not emit invalid 256-color ANSI for default foreground and background" do
        renderer = Fatty::AnsiRenderer.new(
          width: 80,
          palette: {
            markdown_strong: {
              fg: Fatty::Color::DEFAULT_INDEX,
              bg: Fatty::Color::DEFAULT_INDEX,
              fg_rgb: nil,
              bg_rgb: nil,
              attrs: [:bold],
            },
          },
        )

        rendered = renderer.double_emphasis("bold")

        expect(rendered).to include("\e[1m")
        expect(rendered).not_to include("38;5;-1")
        expect(rendered).not_to include("48;5;-1")
        expect(rendered).not_to include("-1")
      end
    end

    describe "#block_code" do
      it "uses the selected Rouge theme for code blocks" do
        renderer = Fatty::AnsiRenderer.new(
          theme: { markdown_code_theme: :solarized_light },
          truecolor: true,
        )

        expect(Rouge::Formatters::TerminalTruecolor)
          .to receive(:new)
                .with(Rouge::Themes::Base16::Solarized.mode(:light))
                .and_call_original

        renderer.block_code("puts 'hi'\n", "ruby")
      end
    end

    describe "#paragraph" do
      it "preserves hard break sentinels" do
        renderer = AnsiRenderer.new(width: 80)

        html_break = renderer.render_inline_html("one<br>two")
        expect(renderer.paragraph(html_break)).to include("one\ntwo")
      end

      it "wraps  ordinary source newlines" do
        renderer = AnsiRenderer.new(width: 80)

        normal_newline = "one\ntwo"
        expect(renderer.paragraph(normal_newline)).to include("one two")
      end
    end
  end
end
