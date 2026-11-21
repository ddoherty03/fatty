# frozen_string_literal: true

module Fatty
  RSpec.describe OutputBuffer do
    describe "#append" do
      it "stores lines" do
        buffer = Fatty::OutputBuffer.new

        buffer.append("one\ntwo\n")

        expect(buffer.lines).to eq(["one", "two"])
      end

      it "replaces malformed UTF-8 without losing lines or roles" do
        buffer = Fatty::OutputBuffer.new
        text = "bad\xff\nnext"
        buffer.append(text, role: :warn)
        expect(buffer.lines).to eq(["bad�", "next"])
        expect(buffer.fragments_for(0).first.text).to eq("bad�")
        expect(buffer.fragments_for(0).first.role).to eq(:warn)
        expect(text.valid_encoding?).to be(false)
      end

      it "stores role fragments" do
        buffer = Fatty::OutputBuffer.new

        buffer.append("hello\n", role: :good)

        expect(
          buffer.fragments_for(0).map { |fragment| [fragment.text, fragment.role] },
        ).to eq([["hello", :good]])
      end

      it "preserves different roles within a partial line" do
        buffer = Fatty::OutputBuffer.new

        buffer.append("ordinary ")
        buffer.append("good\n", role: :good)

        expect(buffer.lines).to eq(["ordinary good"])
        expect(
          buffer.fragments_for(0).map { |fragment| [fragment.text, fragment.role] },
        ).to eq(
          [
            ["ordinary ", nil],
            ["good", :good],
          ],
        )
      end
    end

    describe "#clear" do
      it "clears lines and role fragments" do
        buffer = Fatty::OutputBuffer.new

        buffer.append("good\n", role: :good)
        buffer.clear
        buffer.append("info\n", role: :info)

        expect(buffer.lines).to eq(["info"])
        expect(
          buffer.fragments_for(0).map { |fragment| [fragment.text, fragment.role] },
        ).to eq([["info", :info]])
      end
    end
  end
end
