# frozen_string_literal: true

require "tmpdir"

module Fatty
  RSpec.describe History do
    describe "#initialize" do
      it "does not load from disk when path is nil" do
        history = Fatty::History.new(path: nil)
        expect(history.to_a).to eq([])
      end
    end

    describe "class methods" do
      before { Fatty::History.reset_instances! }

      it "returns the same default history object" do
        expect(Fatty::History.default).to equal(Fatty::History.default)
      end
    end

    describe "main methods" do
      let(:hist_path) { "/tmp/spec_history" }
      let(:hist) { History.new(path: hist_path, max: 5) }

      before do
        FileUtils.rm_f(hist_path)
        FileUtils.touch(hist_path)
      end

      it "starts empty and has no navigable history" do
        expect(hist.previous("x")).to eq("x")
        expect(hist.next).to eq("")
      end

      it "adds command entries and resets cursor" do
        hist.add("one")
        hist.add("two")

        expect(hist.entries.map(&:text)).to eq(["one", "two"])
        expect(hist.entries.map(&:kind)).to eq([:command, :command])
      end

      it "previous returns scratch on first call then walks backwards" do
        hist.add("one")
        hist.add("two")

        expect(hist.previous('')).to eq("two")
        expect(hist.previous("ignored")).to eq("one")
        expect(hist.previous("ignored")).to eq("one")
      end

      it "next walks forward and returns scratch when reaching end" do
        hist.add("one")
        hist.add("two")

        expect(hist.previous("")).to eq("two")
        expect(hist.previous("")).to eq("one")

        expect(hist.next).to eq("two")
        expect(hist.next).to eq("")
        expect(hist.next).to eq("")
      end

      it "uses the current buffer as a prefix for history traversal" do
        hist.add("git status")
        hist.add("ls")
        hist.add("git log")
        f = Fatty::InputField.new(prompt: '> ', history: hist)

        f.buffer.replace("git")
        f.history_prev
        expect(f.buffer.text).to eq("git log")
        f.history_prev
        expect(f.buffer.text).to eq("git status")
        f.history_next
        expect(f.buffer.text).to eq("git log")
        f.history_next
        expect(f.buffer.text).to eq("git")
      end

      it "load reads an existing legacy history file" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "hist")
          File.write(path, "one\ntwo\n")

          h = History.new(path: path)

          expect(h.entries.map(&:text)).to eq(["one", "two"])
          expect(h.entries.map(&:kind)).to eq([:command, :command])
          expect(h.previous("")).to eq("two")
        end
      end

      it "Fatty::History#add appends JSONL entries to the history file" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "hist")
          h = History.new(path: path)

          h.add("one")
          h.add("two")

          lines = File.readlines(path, chomp: true)
          parsed = lines.map { |line| JSON.parse(line) }

          expect(parsed.map { |row| row["text"] }).to eq(["one", "two"])
          expect(parsed.map { |row| row["kind"] }).to eq(["command", "command"])
          expect(parsed.all? { |row| row.key?("stamp") }).to be(true)
          expect(parsed.map { |row| row["ctx"] }).to eq([{}, {}])
        end
      end

      it "handles a missing file path by creating and writing the file" do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "junk_history")
          h = History.new(path: path)

          expect { h.add("one") }.not_to raise_error
          expect(h.entries.map(&:text)).to eq(["one"])
          expect(File).to exist(path)
        end
      end

      it "does not add blank or whitespace-only lines" do
        hist.add("   ")
        hist.add("")
        hist.add("\t")
        hist.add("ok")

        expect(hist.entries.map(&:text)).to eq(["ok"])
      end

      it "Fatty::History#truncate! enforces max size in memory" do
        hist.add("1")
        hist.add("2")
        hist.add("3")
        hist.add("4")
        hist.add("5")
        hist.add("6")
        hist.add("7")

        expect(hist.entries.map(&:text)).to eq(["3", "4", "5", "6", "7"])
      end

      it "prioritizes entries matching ctx but still falls back to other entries" do
        hist.add("ls", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("git status", kind: :command, ctx: { pwd: "/beta" })
        hist.add("bundle exec rspec", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("rake test", kind: :command, ctx: { pwd: "/gamma" })

        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" }))
          .to eq("bundle exec rspec")
        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" }))
          .to eq("ls")
        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" }))
          .to eq("rake test")
        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" }))
          .to eq("git status")
      end

      it "keeps a separate cursor per ctx" do
        hist.add("ls", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("git status", kind: :command, ctx: { pwd: "/beta" })
        hist.add("bundle exec rspec", kind: :command, ctx: { pwd: "/alpha" })

        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" })).to eq("bundle exec rspec")
        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/beta" })).to eq("git status")
        expect(hist.previous_for(:command, current: "", ctx: { pwd: "/alpha" })).to eq("ls")
      end

      it "uses the current buffer as a prefix filter on first previous_for" do
        hist.add("git status", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("ls", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("git commit", kind: :command, ctx: { pwd: "/beta" })
        hist.add("git log", kind: :command, ctx: { pwd: "/alpha" })

        expect(hist.previous_for(:command, current: "git", ctx: { pwd: "/alpha" }))
          .to eq("git log")
        expect(hist.previous_for(:command, current: "ignored", ctx: { pwd: "/alpha" }))
          .to eq("git status")
        expect(hist.previous_for(:command, current: "ignored", ctx: { pwd: "/alpha" }))
          .to eq("git commit")
      end

      it "returns the current text unchanged when no prefix matches" do
        hist.add("ls", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("pwd", kind: :command, ctx: { pwd: "/alpha" })

        expect(hist.previous_for(:command, current: "git", ctx: { pwd: "/alpha" }))
          .to eq("git")
      end

      it "keeps prefix filtering active while traversing next_for" do
        hist.add("git status", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("ls", kind: :command, ctx: { pwd: "/alpha" })
        hist.add("git log", kind: :command, ctx: { pwd: "/alpha" })

        expect(hist.previous_for(:command, current: "git", ctx: { pwd: "/alpha" }))
          .to eq("git log")
        expect(hist.previous_for(:command, current: "ignored", ctx: { pwd: "/alpha" }))
          .to eq("git status")

        expect(hist.next_for(:command, ctx: { pwd: "/alpha" })).to eq("git log")
        expect(hist.next_for(:command, ctx: { pwd: "/alpha" })).to eq("git")
        expect(hist.next_for(:command, ctx: { pwd: "/alpha" })).to eq("")
      end

      it "computes an autosuggestion from the most recent history prefix match" do
        h = History.new(path: hist_path)
        h.add("git status")
        h.add("git stash")

        f = InputField.new(prompt: "> ", history: h)
        f.act_on(:insert, "git st")

        expect(f.autosuggestion).to eq("git stash")
        expect(f.autosuggestion_visible?).to be(true)
        expect(f.autosuggestion_suffix).to eq("ash")
      end

      it "accept_autosuggestion! replaces the buffer with the suggestion" do
        h = History.new(path: hist_path)
        h.add("git status")

        f = InputField.new(prompt: "> ", history: h)
        f.act_on(:insert, "git st")
        f.accept_autosuggestion!

        expect(f.buffer.text).to eq("git status")
        expect(f.autosuggestion_visible?).to be(false)
      end
    end

    describe "#entries_for" do
      it "returns fallback entries before preferred entries, preserving chronological order within each bucket" do
        h = Fatty::History.new

        h.add("g1", kind: :command, ctx: { pwd: "/tmp/other" })
        h.add("l1", kind: :command, ctx: { pwd: "/tmp/demo" })
        h.add("g2", kind: :command, ctx: { pwd: "/tmp/other" })
        h.add("l2", kind: :command, ctx: { pwd: "/tmp/demo" })

        texts = h.send(:entries_for, :command, ctx: { pwd: "/tmp/demo" }).map(&:text)

        expect(texts).to eq(%w[g1 g2 l1 l2])
      end
    end

    describe "#suggest_for" do
      let(:history) { Fatty::History.new(path: nil) }

      it "prefers ctx-local matches over global matches" do
        history.add("status old", kind: :command, ctx: { pwd: "/other" })
        history.add("status here", kind: :command, ctx: { pwd: "/here" })

        expect(history.suggest_for(:command, prefix: "sta", ctx: { pwd: "/here" }))
          .to eq("status here")
      end

      it "falls back to global matches when no ctx-local match exists" do
        history.add("status old", kind: :command, ctx: { pwd: "/other" })

        expect(history.suggest_for(:command, prefix: "sta", ctx: { pwd: "/here" }))
          .to eq("status old")
      end
    end

    describe "#next_for and #previous_for" do
      it "does not walk past the end of the filtered history list" do
        h = Fatty::History.new

        h.add("global one", kind: :command, ctx: { pwd: "/tmp/other" })
        h.add("local one", kind: :command, ctx: { pwd: "/tmp/demo" })

        expect(h.previous_for(:command, current: '', ctx: { pwd: "/tmp/demo" })).to eq("local one")
        expect(h.next_for(:command, ctx: { pwd: "/tmp/demo" })).to eq("")
      end

      it "returns scratch when navigating down past the newest matching entry" do
        h = Fatty::History.new

        h.add("one", kind: :command, ctx: { pwd: "/tmp/demo" })
        h.add("two", kind: :command, ctx: { pwd: "/tmp/demo" })

        expect(h.previous_for(:command, current: '', ctx: { pwd: "/tmp/demo" })).to eq("two")
        expect(h.next_for(:command, ctx: { pwd: "/tmp/demo" })).to eq("")
      end
    end

    describe "Enumerable access" do
      let(:history) { Fatty::History.new(path: nil) }

      before do
        history.add("ls",   kind: :command,       ctx: { pwd: "/a", proj: "x" })
        history.add("pwd",  kind: :command,       ctx: { pwd: "/b", proj: "x" })
        history.add("foo",  kind: :search_string, ctx: { pwd: "/a" })
        history.add("bar",  kind: :command,       ctx: { pwd: "/a", proj: "y" })
      end

      describe "#each" do
        it "is enumerable" do
          expect(history).to be_a(Enumerable)
        end

        it "yields entries in stored order" do
          expect(history.map(&:text)).to eq(%w[ls pwd foo bar])
        end

        it "returns an enumerator when called without a block" do
          enum = history.each
          expect(enum).to be_an(Enumerator)
          expect(enum.map(&:text)).to eq(%w[ls pwd foo bar])
        end
      end

      describe "#for" do
        it "filters by kind" do
          rows = history.for(kind: :command).to_a
          expect(rows.map(&:text)).to eq(%w[ls pwd bar])
        end

        it "filters by ctx" do
          rows = history.for(ctx: { pwd: "/a" }).to_a
          expect(rows.map(&:text)).to eq(%w[ls foo bar])
        end

        it "uses subset matching for ctx" do
          rows = history.for(ctx: { proj: "x" }).to_a
          expect(rows.map(&:text)).to eq(%w[ls pwd])
        end

        it "filters by kind and ctx together" do
          rows = history.for(kind: :command, ctx: { pwd: "/a" }).to_a
          expect(rows.map(&:text)).to eq(%w[ls bar])
        end

        it "returns an enumerator when called without a block" do
          enum = history.for(kind: :command)
          expect(enum).to be_an(Enumerator)
          expect(enum.map(&:text)).to eq(%w[ls pwd bar])
        end
      end

      describe "#recent" do
        it "returns newest first" do
          expect(history.recent.map(&:text)).to eq(%w[bar foo pwd ls])
        end

        it "filters before applying limit" do
          rows = history.recent(kind: :command, limit: 2)
          expect(rows.map(&:text)).to eq(%w[bar pwd])
        end

        it "filters by ctx" do
          rows = history.recent(ctx: { pwd: "/a" })
          expect(rows.map(&:text)).to eq(%w[bar foo ls])
        end

        it "filters by kind and ctx together" do
          rows = history.recent(kind: :command, ctx: { pwd: "/a" }, limit: 1)
          expect(rows.map(&:text)).to eq(%w[bar])
        end
      end

      describe ".default" do
        it "returns the same object as for_path(:default)" do
          Fatty::History.reset_instances! if Fatty::History.respond_to?(:reset_instances!)

          expect(Fatty::History.default).to equal(Fatty::History.for_path(:default))
        end
      end
    end
  end
end
