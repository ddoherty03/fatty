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

    it "ensures that a Proc becomes a Prompt" do
      expect(Prompt.ensure(-> {"XX"})).to be_a(Prompt)
    end

    it "ensures that any #to_s responding object becomes a Prompt" do
      class Junk
        def to_s
          "willy wonka"
        end
      end
      expect(Prompt.ensure(Junk.new)).to be_a(Prompt)
    end

    it "ensures that any non-#to_s responding object becomes default '> '" do
      class Junk2
      end
      expect(Prompt.ensure(Junk2.new).text).to eq('> ')
    end
  end
end
