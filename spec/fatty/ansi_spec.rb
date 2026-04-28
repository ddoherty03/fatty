# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Ansi do
    def style_of(seg)
      _text, style = seg
      style
    end

    def text_of(seg)
      text, _style = seg
      text
    end

    def segs(str, base: nil)
      Fatty::Ansi.segment(str, base:)
    end

    it "returns a single segment for plain text" do
      segments = segs("hello")
      expect(segments.length).to eq(1)
      expect(text_of(segments[0])).to eq("hello")

      st = style_of(segments[0])
      expect(st.fg).to be_nil
      expect(st.bg).to be_nil
      expect(st.bold).to eq(false)
      expect(st.reverse).to eq(false)
    end

    it "splits around SGR color changes and applies foreground 16-color" do
      segments = segs("a\e[31mred\e[0mz")
      expect(segments.map { |s| text_of(s) }).to eq(["a", "red", "z"])

      st0 = style_of(segments[0])
      expect(st0.fg).to be_nil

      st1 = style_of(segments[1])
      expect(st1.fg).to eq(1) # 31 => 1
      expect(st1.bg).to be_nil

      st2 = style_of(segments[2])
      expect(st2.fg).to be_nil
      expect(st2.bg).to be_nil
    end

    it "applies background 16-color" do
      segments = segs("x\e[44mbluebg\e[0my")
      expect(segments.map { |s| text_of(s) }).to eq(["x", "bluebg", "y"])

      st = style_of(segments[1])
      expect(st.bg).to eq(4) # 44 => 4
      expect(st.fg).to be_nil
    end

    it "supports bright 16-color (90-97 and 100-107)" do
      segments = segs("a\e[93mhi\e[0mb\e[104mzz\e[0mc")
      expect(segments.map { |s| text_of(s) }).to eq(["a", "hi", "b", "zz", "c"])

      st1 = style_of(segments[1])
      expect(st1.fg).to eq(11) # 93 => 8 + 3

      st3 = style_of(segments[3])
      expect(st3.bg).to eq(12) # 104 => 8 + 4
    end

    it "supports 256-color fg via 38;5;n" do
      segments = segs("a\e[38;5;226mY\e[0mz")
      expect(segments.map { |s| text_of(s) }).to eq(["a", "Y", "z"])

      st = style_of(segments[1])
      expect(st.fg).to eq(226)
      expect(st.bg).to be_nil
    end

    it "supports 256-color bg via 48;5;n" do
      segments = segs("a\e[48;5;17mB\e[0mz")
      expect(segments.map { |s| text_of(s) }).to eq(["a", "B", "z"])

      st = style_of(segments[1])
      expect(st.bg).to eq(17)
      expect(st.fg).to be_nil
    end

    it "supports bold and reverse flags" do
      segments = segs("a\e[1mb\e[7mc\e[27md\e[22me\e[0mz")
      expect(segments.map { |s| text_of(s) }).to eq(["a", "b", "c", "d", "ez"])

      st_b = style_of(segments[1])
      expect(st_b.bold).to eq(true)
      expect(st_b.reverse).to eq(false)

      st_c = style_of(segments[2])
      expect(st_c.bold).to eq(true)
      expect(st_c.reverse).to eq(true)

      st_d = style_of(segments[3])
      expect(st_d.bold).to eq(true)
      expect(st_d.reverse).to eq(false)

      st_ez = style_of(segments[4])
      expect(st_ez.bold).to eq(false)
      expect(st_ez.reverse).to eq(false)
    end

    it "ignores unknown SGR codes without breaking parsing" do
      segments = segs("a\e[999mX\e[0mz")
      expect(segments.map { |s| text_of(s) }).to eq(["aXz"])

      st = style_of(segments[0])
      # unknown code should not change anything
      expect(st.fg).to be_nil
      expect(st.bg).to be_nil
      expect(st.bold).to eq(false)
      expect(st.reverse).to eq(false)
    end

    it "treats an unrecognized ESC sequence as literal ESC" do
      segments = segs("a\eZb")
      expect(segments.length).to eq(1)
      expect(text_of(segments[0])).to eq("a\eZb")
    end

    it "consumes non-SGR CSI sequences (does not emit them as text)" do
      # ESC [ 2 J  (clear screen) should be consumed by parser as 'some other CSI'
      segments = segs("a\e[2Jb")
      expect(segments.length).to eq(1)
      expect(text_of(segments[0])).to eq("ab")
    end

    it "applies base style as the starting point" do
      base = Fatty::Ansi::Style.new(fg: 2, bg: 4, bold: true, reverse: false)
      segments = segs("a\e[0mb", base:)

      expect(segments.map { |s| text_of(s) }).to eq(["a", "b"])

      st_a = style_of(segments[0])
      expect(st_a.fg).to eq(2)
      expect(st_a.bg).to eq(4)
      expect(st_a.bold).to eq(true)
      expect(st_a.reverse).to eq(false)

      st_b = style_of(segments[1])
      expect(st_b.fg).to be_nil
      expect(st_b.bg).to be_nil
      expect(st_b.bold).to eq(false)
      expect(st_b.reverse).to eq(false)
    end

    it "preserves UTF-8 characters while segmenting ANSI text" do
      segments = Fatty::Ansi.segment("Demo \e[32m▓▒░\e[0m done")

      text = segments.map { |segment_text, _style| segment_text }.join
      expect(text).to eq("Demo ▓▒░ done")
    end

    it "returns plain text without ANSI escape sequences" do
      text = Fatty::Ansi.plain_text("a\e[31mred\e[0m▓")

      expect(text).to eq("ared▓")
    end

    it "returns visible length without counting ANSI escape sequences" do
      length = Fatty::Ansi.visible_length("a\e[31mred\e[0m▓")

      expect(length).to eq(5)
    end

    it "does not count combining strikethrough marks as visible width" do
      text = "strike".each_char.map { |ch| "#{ch}\u0336" }.join
      expect(Fatty::Ansi.visible_length(text)).to eq(6)
    end

    it "does not count combining marks inside ANSI-styled text" do
      struck = "ok".each_char.map { |ch| "#{ch}\u0336" }.join
      text = Rainbow(struck).faint.to_s
      expect(Fatty::Ansi.visible_length(text)).to eq(2)
    end

    it "truncates by visible characters while preserving styles" do
      text = Fatty::Ansi.truncate_visible("a\e[31mred\e[0m▓", 4)

      expect(Fatty::Ansi.plain_text(text)).to eq("ared")
      expect(Fatty::Ansi.visible_length(text)).to eq(4)
      expect(text).to end_with("\e[0m")
    end
  end
end
