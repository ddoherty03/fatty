# frozen_string_literal: true

require "tmpdir"

module FatTerm
  RSpec.describe History do
    it "starts empty and has no navigable history" do
      h = History.new
      expect(h.previous("x")).to eq("x")
      expect(h.next).to eq("")
    end

    it "adds entries and resets cursor" do
      h = History.new
      h.add("one")
      h.add("two")
      expect(h.entries).to eq(["one", "two"])
    end

    it "previous returns scratch on first call then walks backwards" do
      h = History.new
      h.add("one")
      h.add("two")

      cur = "typing"
      expect(h.previous(cur)).to eq("two")
      expect(h.previous("ignored")).to eq("one")
      expect(h.previous("ignored")).to eq("one")
    end

    it "next walks forward and returns scratch when reaching end" do
      h = History.new
      h.add("one")
      h.add("two")

      expect(h.previous("typing")).to eq("two")
      expect(h.previous("ignored")).to eq("one")

      expect(h.next).to eq("two")          # index = 1
      expect(h.next).to eq("typing")       # end -> scratch + reset
      expect(h.next).to eq("")             # no active cursor
    end

    it "load reads an existing history file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "hist")
        File.write(path, "one\ntwo\n")

        h = History.new(path: path)

        expect(h.entries).to eq(["one", "two"])
        expect(h.previous("x")).to eq("two")
      end
    end

    it "add appends to history file and fsyncs" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "hist")
        h = History.new(path: path)

        h.add("one")
        h.add("two")

        expect(File.read(path)).to eq("one\ntwo\n")
      end
    end

    it "handles missing path by not writing" do
      h = History.new(path: nil)
      expect { h.add("one") }.not_to raise_error
      expect(h.entries).to eq(["one"])
    end

    it "does not add blank/whitespace-only lines" do
      h = History.new
      h.add("   ")
      h.add("")
      h.add("\t")
      h.add("ok")
      expect(h.entries).to eq(["ok"])
    end

    it "can enforce max size" do
      h = History.new(max: 3)
      h.add("1")
      h.add("2")
      h.add("3")
      h.add("4")
      expect(h.entries).to eq(["2", "3", "4"])
    end
  end
end
