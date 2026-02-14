# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module FatTerm
  RSpec.describe Color do
    describe ".resolve" do
      it "accepts ANSI names (case-insensitive, punctuation-insensitive)" do
        expect(Color.resolve("red", available_colors: 256)).to eq(1)
        expect(Color.resolve("Bright-Red", available_colors: 256)).to eq(9)
        expect(Color.resolve("bright_red", available_colors: 256)).to eq(9)
      end

      it "accepts integers" do
        expect(Color.resolve(17, available_colors: 256)).to eq(17)
        expect(Color.resolve(0, available_colors: 256)).to eq(0)
      end

      it "accepts default" do
        expect(Color.resolve("default", available_colors: 256)).to eq(Color::DEFAULT_INDEX)
        expect(Color.resolve(nil, available_colors: 256)).to eq(Color::DEFAULT_INDEX)
      end

      it "accepts hex colors (#rgb and #rrggbb)" do
        # pure blue: 0,0,255 -> xterm cube index 21
        expect(Color.resolve("#0000ff", available_colors: 256)).to eq(21)
        expect(Color.resolve("#00f", available_colors: 256)).to eq(21)
      end

      it "accepts small alias set" do
        expect(Color.resolve("navy", available_colors: 256)).to eq(17)
        expect(Color.resolve("dark_blue", available_colors: 256)).to eq(18)
      end

      it "maps extended colors down to ANSI 16-color when only 16 colors are available" do
        # xterm 226 is bright yellow in the 6x6x6 cube (255,255,0)
        # should downmap close to ANSI bright_yellow (11)
        expect(Color.resolve(226, available_colors: 16)).to eq(11)

        # and hex should also downmap similarly
        expect(Color.resolve("#ffff00", available_colors: 16)).to eq(11)
      end

      it "maps X11 names via the bundled rgb.txt (nearest match)" do
        Dir.mktmpdir("fat_term_color_spec") do |dir|
          colors_dir = File.join(dir, "colors")
          FileUtils.mkdir_p(colors_dir)

          rgb_path = File.join(colors_dir, "rgb.txt")
          File.write(rgb_path, <<~TXT)
            ! minimal rgb.txt for tests
            25 25 112 MidnightBlue
            255 255 0 LightYellow
          TXT

          stub_const("FatTerm::Color::RGB_TXT_PATH", rgb_path)
          Color.instance_variable_set(:@x11_table, nil)

          idx = Color.resolve("MidnightBlue", available_colors: 256)
          expect(idx).to eq(Color.xterm_index_for_rgb(25, 25, 112))

          idx2 = Color.resolve("light yellow", available_colors: 256)
          expect(idx2).to eq(Color.xterm_index_for_rgb(255, 255, 0))
        end
      end

      it "returns default for unknown names" do
        expect(Color.resolve("definitely_not_a_color", available_colors: 256)).to eq(Color::DEFAULT_INDEX)
      end
    end
  end
end
