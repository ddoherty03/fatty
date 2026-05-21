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
  end
end
