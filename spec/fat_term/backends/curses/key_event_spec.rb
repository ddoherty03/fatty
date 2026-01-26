# frozen_string_literal: true

module FatTerm
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
    end
  end
end
