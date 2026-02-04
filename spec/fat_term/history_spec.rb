# frozen_string_literal: true

require "tmpdir"

module FatTerm
  RSpec.describe History do
    let(:hist_path) { "/tmp/spec_history" }
    let(:hist) { History.new(path: hist_path, max: 5) }

    before do
      FileUtils.rm(hist_path) if File.readable?(hist_path)
      FileUtils.touch(hist_path)
    end

    it "starts empty and has no navigable history" do
      expect(hist.previous("x")).to eq("x")
      expect(hist.next).to eq("")
    end

    it "adds entries and resets cursor" do
      hist.add("one")
      hist.add("two")
      expect(hist.entries).to eq(["one", "two"])
    end

    it "previous returns scratch on first call then walks backwards" do
      hist.add("one")
      hist.add("two")

      cur = "typing"
      expect(hist.previous(cur)).to eq("two")
      expect(hist.previous("ignored")).to eq("one")
      expect(hist.previous("ignored")).to eq("one")
    end

    it "next walks forward and returns scratch when reaching end" do
      hist.add("one")
      hist.add("two")

      expect(hist.previous("typing")).to eq("two")
      expect(hist.previous("ignored")).to eq("one")

      expect(hist.next).to eq("two")          # index = 1
      expect(hist.next).to eq("typing")       # end -> scratch + reset
      expect(hist.next).to eq("")             # no active cursor
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
      junk_path = "/tmp/junk_history"
      FileUtils.rm(junk_path) if File.readable?(junk_path)
      h = History.new(path: junk_path)
      expect { h.add("one") }.not_to raise_error
      expect(h.entries).to eq(["one"])
    end

    it "does not add blank/whitespace-only lines" do
      hist.add("   ")
      hist.add("")
      hist.add("\t")
      hist.add("ok")
      expect(hist.entries).to eq(["ok"])
    end

    it "can enforce max size" do
      # NB: hist has a max size of 5
      hist.add("1")
      hist.add("2")
      hist.add("3")
      hist.add("4")
      hist.add("5")
      hist.add("6")
      hist.add("7")
      # Keep only the last 5 entries
      expect(hist.entries).to eq(["3", "4", "5", "6", "7"])
    end
  end
end
