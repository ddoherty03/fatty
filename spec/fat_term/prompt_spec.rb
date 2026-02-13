# frozen_string_literal: true

module FatTerm
  RSpec.describe Prompt do
    it "defaults to a '> ' prompt" do
      p = Prompt.new
      expect(p.text).to eq("> ")
    end

    it "can take any to_s able value for the prompt" do
      p = Prompt.new('XXXXXX->')
      expect(p.text).to eq('XXXXXX->')
      p = Prompt.new(888)
      expect(p.text).to eq('888')
    end

    it "returns the value of the block" do
      p = Prompt.new { "> " }
      expect(p.text).to eq("> ")
    end

    it "evaluates the block each time" do
      i = 0
      p = Prompt.new do
        i += 1
        "#{i}> "
      end
      expect(p.text).to eq("1> ")
      expect(p.text).to eq("2> ")
    end

    it "coerces nil to empty string" do
      p = Prompt.new { nil }
      expect(p.text).to eq("")
    end

    it "always returns a string" do
      p = Prompt.new { 123 }
      expect(p.text).to eq("123")
    end

    describe ".ensure" do
      it "returns the same Prompt instance" do
        p = Prompt.new("X ")
        expect(Prompt.ensure(p)).to equal(p)
      end

      it "wraps a Proc as a dynamic prompt" do
        pr = -> { "Y " }
        p = Prompt.ensure(pr)
        expect(p.text).to eq("Y ")
      end

      it "wraps a string as a fixed prompt" do
        p = Prompt.ensure("I-search: ")
        expect(p.text).to eq("I-search: ")
      end

      it "uses default prompt for nil" do
        p = Prompt.ensure(nil)
        expect(p.text).to eq(Prompt::DEFAULT)
      end

      it "ensures that a Proc becomes a Prompt" do
        expect(Prompt.ensure(-> {"XX"})).to be_a(Prompt)
      end

      it "ensures that any other object becomes default '> '" do
        class Junk2
        end
        expect(Prompt.ensure(Junk2.new).text).to eq('> ')
      end

      it "round-trips ensure through initialize" do
        values = [nil, "A ", -> { "B " }, Prompt.new("C ")]

        values.each do |v|
          p = Prompt.ensure(v)
          expect(p).to be_a(Prompt)
          expect(p.text).to be_a(String)
        end
      end
    end
  end
end
