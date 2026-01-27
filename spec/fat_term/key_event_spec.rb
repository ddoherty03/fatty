# frozen_string_literal: true

module FatTerm
  RSpec.describe KeyEvent do
    describe "#decoded?" do
      it "is true when key is a Symbol" do
        expect(KeyEvent.new(key: :left).decoded?).to be(true)
      end

      it "is false when key is not a Symbol" do
        expect(KeyEvent.new(key: "x", text: "x").decoded?).to be(false)
      end
    end

    describe "text invariant" do
      it "keeps text for unmodified printable keys" do
        e = KeyEvent.new(key: "x", text: "x", ctrl: false, meta: false)
        expect(e.text).to eq("x")
      end

      it "clears text for ctrl chords" do
        e = KeyEvent.new(key: :x, text: "x", ctrl: true)
        expect(e.text).to be_nil
      end

      it "clears text for meta chords" do
        e = KeyEvent.new(key: :x, text: "x", meta: true)
        expect(e.text).to be_nil
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
