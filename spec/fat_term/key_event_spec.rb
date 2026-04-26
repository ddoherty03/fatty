# frozen_string_literal: true

module Fatty
  RSpec.describe KeyEvent do
    describe "attributes and defaults" do
      it "stores key and defaults modifiers to false" do
        e = KeyEvent.new(key: :a)

        expect(e.key).to eq(:a)
        expect(e.text).to be_nil
        expect(e.raw).to be_nil

        expect(e.ctrl).to be(false)
        expect(e.meta).to be(false)
        expect(e.shift).to be(false)

        expect(e.ctrl?).to be(false)
        expect(e.meta?).to be(false)
        expect(e.shift?).to be(false)
      end

      it "stores text/raw/modifiers when provided" do
        e = KeyEvent.new(
          key: :d,
          text: "d",
          raw: [27, "d"],
          ctrl: true,
          meta: true,
          shift: true,
        )

        expect(e.key).to eq(:d)
        expect(e.text).to be_nil
        expect(e.raw).to eq([27, "d"])
        expect(e.ctrl?).to be(true)
        expect(e.meta?).to be(true)
        expect(e.shift?).to be(true)
      end

      it "sets text if ctrl or meta false" do
        e = KeyEvent.new(
          key: :d,
          text: "d",
          raw: "d",
        )

        expect(e.key).to eq(:d)
        expect(e.text).to eq("d")
        expect(e.raw).to eq("d")
        expect(e.ctrl?).to be(false)
        expect(e.meta?).to be(false)
        expect(e.shift?).to be(false)
      end
    end

    describe "#decoded?" do
      it "is true when key is a Symbol" do
        expect(KeyEvent.new(key: :left).decoded?).to be(true)
      end

      it "is false when key is an Integer (unrecognized/raw code)" do
        expect(KeyEvent.new(key: 555, raw: 555).decoded?).to be(false)
      end

      it "is false when key is not a Symbol" do
        expect(KeyEvent.new(key: "x", text: "x").decoded?).to be(false)
      end
    end

    describe "value identity" do
      it "treats key+modifiers as identity (ignores raw/text)" do
        a = KeyEvent.new(key: :x, ctrl: true, meta: false, shift: false, raw: 24, text: nil)
        b = KeyEvent.new(key: :x, ctrl: true, meta: false, shift: false, raw: 999, text: "x")

        expect(a).to eq(b)
        expect(a).to eql(b)
        expect(a.hash).to eq(b.hash)
      end

      it "does not consider different modifiers equal" do
        a = KeyEvent.new(key: :x, ctrl: true)
        b = KeyEvent.new(key: :x, ctrl: false)

        expect(a).not_to eq(b)
      end

      it "works as a Hash key" do
        a = KeyEvent.new(key: :x, ctrl: true)
        b = KeyEvent.new(key: :x, ctrl: true)

        h = { a => :ok }
        expect(h[b]).to eq(:ok)
      end
    end
  end
end
