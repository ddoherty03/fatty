# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Search do
  describe ".split_terms" do
    it "splits on whitespace and drops empties" do
      expect(Fatty::Search.split_terms("  foo   bar baz  ")).to eq(["foo", "bar", "baz"])
    end
  end

  describe ".match_all_terms?" do
    it "matches empty query" do
      expect(Fatty::Search.match_all_terms?("foo bar", "")).to be(true)
    end

    it "matches one term" do
      expect(Fatty::Search.match_all_terms?("foo bar", "foo")).to be(true)
    end

    it "matches multiple terms in any order" do
      expect(Fatty::Search.match_all_terms?("foo bar baz", "baz foo")).to be(true)
    end

    it "fails when one term is missing" do
      expect(Fatty::Search.match_all_terms?("foo bar baz", "foo qux")).to be(false)
    end

    it "matches case-insensitively" do
      expect(Fatty::Search.match_all_terms?("Foo Bar", "foo bar")).to be(true)
    end
  end

  describe ".compile_regexp" do
    it "builds a regex that matches all terms in any order" do
      re = Fatty::Search.compile_regexp("foo bar", regex: false)
      expect("foo xxx bar").to match(re)
      expect("bar xxx foo").to match(re)
      expect("foo xxx baz").not_to match(re)
    end

    it "is case-insensitive when pattern has no uppercase letters" do
      re = Fatty::Search.compile_regexp("foo", regex: false)
      expect("FOO").to match(re)
    end

    it "is case-sensitive when pattern includes uppercase letters" do
      re = Fatty::Search.compile_regexp("Foo", regex: false)
      expect("Foo").to match(re)
      expect("foo").not_to match(re)
    end

    it "passes regex patterns through unchanged when regex is true" do
      re = Fatty::Search.compile_regexp("f.o", regex: true)
      expect("foo").to match(re)
    end
  end
end
