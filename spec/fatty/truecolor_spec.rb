# frozen_string_literal: true

require "spec_helper"
require "stringio"

module Fatty
  RSpec.describe "truecolor support" do
    class TruecolorSpecWindow
      attr_reader :maxx
      attr_reader :writes

      def initialize(maxx: 12)
        @maxx = maxx
        @writes = []
      end

      def bkgdset(attr)
        @writes << [:bkgdset, attr]
      end

      def erase
        @writes << [:erase]
      end

      def attrset(attr)
        @writes << [:attrset, attr]
      end

      def setpos(row, col)
        @writes << [:setpos, row, col]
      end

      def addstr(text)
        @writes << [:addstr, text]
      end

      def noutrefresh
        @writes << [:noutrefresh]
      end
    end

    class TruecolorSpecContext
      attr_reader :status_win, :palette, :truecolor

      def initialize(truecolor:)
        @truecolor = truecolor
        @status_win = TruecolorSpecWindow.new(maxx: 12)
        @palette = {
          good: {
            pair: 1,
            fg_rgb: [0, 0, 0],
            bg_rgb: [240, 248, 255],
            attrs: [],
          },
        }
      end
    end

    it "preserves exact RGB values in palette entries" do
      registry = Fatty::Themes::Registry.new

      registry.add(
        {
          name: :truecolor_spec,
          inherit: nil,
          roles: {
            good: {
              fg: "black",
              bg: "AliceBlue",
            },
          },
          markdown: {},
        },
      )

      allow(Fatty::Themes::Manager)
        .to receive(:roles)
              .with(:truecolor_spec)
              .and_return(Fatty::Themes::Resolver.resolve(registry, :truecolor_spec)[:roles])

      palette = Fatty::Colors::Palette.build(
        { theme: :truecolor_spec },
        available_colors: 256,
      )

      expect(palette[:good][:fg_rgb]).to eq([0, 0, 0])
      expect(palette[:good][:bg_rgb]).to eq([240, 248, 255])
    end

    it "renders a truecolor status overlay when truecolor is enabled" do
      screen = Fatty::Screen.new(rows: 10, cols: 12, status_rows: 1)
      context = TruecolorSpecContext.new(truecolor: true)

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      allow(::Curses).to receive(:color_pair).and_return(0)

      renderer = Fatty::Curses::Renderer.new(context:, screen:)
      renderer.begin_frame
      renderer.render_status("good hello", role: :good)

      pending = renderer.instance_variable_get(:@pending_ansi_draws)

      expect(pending.length).to eq(1)
      expect(pending.first[:type]).to eq(:segments_line)
      expect(pending.first[:segments].first[:role]).to eq(:good)

      renderer.flush_ansi_overlay

      expect(out.string).to include("38;2;0;0;0")
      expect(out.string).to include("48;2;240;248;255")
      expect(out.string).to include("good hello")
    ensure
      $stdout = original_stdout
    end

    it "does not render a truecolor status overlay when truecolor is disabled" do
      screen = Fatty::Screen.new(rows: 10, cols: 12, status_rows: 1)
      context = TruecolorSpecContext.new(truecolor: false)
      renderer = Fatty::Curses::Renderer.new(context:, screen:)

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      allow(::Curses).to receive(:color_pair).and_return(0)
      allow(::Curses).to receive(:doupdate)

      renderer.begin_frame
      renderer.render_status("good hello", role: :status)
      renderer.finish_frame

      expect(out.string).to eq("")
    ensure
      $stdout = original_stdout
    end
  end
end
