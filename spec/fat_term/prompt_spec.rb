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
  end
end
