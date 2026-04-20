# frozen_string_literal: true

module FatTerm
  RSpec.describe History::Entry do
    describe "#initialize" do
      it "normalizes text to a string" do
        entry = History::Entry.new(text: 123)

        expect(entry.text).to eq("123")
      end

      it "normalizes kind to a symbol" do
        entry = History::Entry.new(text: "abc", kind: "search_string")

        expect(entry.kind).to eq(:search_string)
      end

      it "normalizes ctx to a hash with string keys" do
        entry = History::Entry.new(
          text: "abc",
          ctx: { pwd: "/tmp", "mode" => "pager" },
        )

        expect(entry.ctx).to eq(
          "pwd" => "/tmp",
          "mode" => "pager",
        )
      end

      it "uses an empty hash when ctx is nil" do
        entry = History::Entry.new(text: "abc", ctx: nil)

        expect(entry.ctx).to eq({})
      end

      it "uses an empty hash when ctx is not a hash" do
        entry = History::Entry.new(text: "abc", ctx: "nope")

        expect(entry.ctx).to eq({})
      end

      it "uses the provided stamp" do
        stamp = Time.local(2026, 2, 21, 12, 34, 56)
        entry = History::Entry.new(text: "abc", stamp: stamp)

        expect(entry.stamp).to eq(stamp)
      end

      it "defaults stamp to the current time" do
        before = Time.now
        entry = History::Entry.new(text: "abc")
        after = Time.now

        expect(entry.stamp).to be_between(before, after)
      end
    end

    describe "#command?" do
      it "is true for command entries" do
        entry = History::Entry.new(text: "ls", kind: :command)

        expect(entry.command?).to be(true)
      end

      it "is false for non-command entries" do
        entry = History::Entry.new(text: "foo", kind: :search_string)

        expect(entry.command?).to be(false)
      end
    end

    describe "#search?" do
      it "is true for search_string entries" do
        entry = History::Entry.new(text: "foo", kind: :search_string)

        expect(entry.search?).to be(true)
      end

      it "is true for search_regex entries" do
        entry = History::Entry.new(text: "foo.*", kind: :search_regex)

        expect(entry.search?).to be(true)
      end

      it "is false for command entries" do
        entry = History::Entry.new(text: "ls", kind: :command)

        expect(entry.search?).to be(false)
      end
    end

    describe "#ctx_fetch" do
      it "fetches using symbol keys" do
        entry = History::Entry.new(text: "abc", ctx: { pwd: "/tmp" })

        expect(entry.ctx_fetch(:pwd)).to eq("/tmp")
      end

      it "fetches using string keys" do
        entry = History::Entry.new(text: "abc", ctx: { pwd: "/tmp" })

        expect(entry.ctx_fetch("pwd")).to eq("/tmp")
      end

      it "returns the default when the key is missing" do
        entry = History::Entry.new(text: "abc", ctx: {})

        expect(entry.ctx_fetch(:missing, "fallback")).to eq("fallback")
      end

      it "returns nil when the key is missing and no default is given" do
        entry = History::Entry.new(text: "abc", ctx: {})

        expect(entry.ctx_fetch(:missing)).to be_nil
      end
    end

    describe "#to_h" do
      it "serializes to a plain hash" do
        stamp = Time.local(2026, 2, 21, 12, 34, 56)
        entry = History::Entry.new(
          text: "foo",
          kind: :search_string,
          ctx: { pwd: "/tmp" },
          stamp: stamp,
        )

        expect(entry.to_h).to eq(
          "text" => "foo",
          "kind" => "search_string",
          "ctx" => { "pwd" => "/tmp" },
          "stamp" => stamp.iso8601,
        )
      end
    end

    describe ".from_h" do
      it "builds an entry from a string-keyed hash" do
        stamp = Time.local(2026, 2, 21, 12, 34, 56)

        entry = History::Entry.from_h(
          "text" => "foo",
          "kind" => "search_regex",
          "ctx" => { "pwd" => "/tmp" },
          "stamp" => stamp.iso8601,
        )

        expect(entry.text).to eq("foo")
        expect(entry.kind).to eq(:search_regex)
        expect(entry.ctx).to eq("pwd" => "/tmp")
        expect(entry.stamp.iso8601).to eq(stamp.iso8601)
      end

      it "loads history kinds as symbols" do
        entry = FatTerm::History::Entry.from_h(
          "text" => "echo four score",
          "kind" => "command",
          "ctx" => { "pwd" => "/tmp" },
        )

        expect(entry.kind).to eq(:command)
      end

      it "builds an entry from a symbol-keyed hash" do
        entry = History::Entry.from_h(
          text: "foo",
          kind: "command",
          ctx: { pwd: "/tmp" },
        )

        expect(entry.text).to eq("foo")
        expect(entry.kind).to eq(:command)
        expect(entry.ctx).to eq("pwd" => "/tmp")
      end

      it "defaults text and kind when missing" do
        entry = History::Entry.from_h({})

        expect(entry.text).to eq("")
        expect(entry.kind).to eq(:command)
        expect(entry.ctx).to eq({})
      end

      it "uses a nil or invalid stamp as current time fallback" do
        before = Time.now
        entry = History::Entry.from_h(
          "text" => "foo",
          "stamp" => "not-a-time",
        )
        after = Time.now

        expect(entry.stamp).to be_between(before, after)
      end
    end
  end
end
