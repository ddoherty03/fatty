# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module FatTerm
  RSpec.describe InputField do
    let(:tmpdir) { Dir.mktmpdir }
    let(:hist_path) { File.join(tmpdir, "history") }

    after do
      FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir)
    end

    def prompt(text = "> ")
      Prompt.new { text }
    end

    it "starts empty with prompt text" do
      f = InputField.new(prompt: prompt("p> "))
      expect(f.prompt_text).to eq("p> ")
      expect(f.empty?).to be(true)
      expect(f.buffer.text).to eq("")
      expect(f.buffer.cursor).to eq(0)
    end

    it "cursor_x is prompt_width + buffer cursor (exact)" do
      f = InputField.new(prompt: prompt("p> "))
      f.act_on(:insert, "abc") # via actions to prove dispatch works with args
      expect(f.cursor_x).to eq("p> ".length + 3)

      f.act_on(:move_left)
      expect(f.cursor_x).to eq("p> ".length + 2)
    end

    it "accept_line returns line, clears buffer, and adds to history" do
      h = History.new(path: hist_path)
      f = InputField.new(prompt: prompt("> "), history: h)

      f.act_on(:insert, "hello")
      line = f.act_on(:accept_line)

      expect(line).to eq("hello")
      expect(f.buffer.text).to eq("")
      expect(f.buffer.cursor).to eq(0)
      expect(h.entries.map(&:text)).to eq(["hello"])
      expect(h.entries.map(&:kind)).to eq([:command])
    end

    it "accept_line adds to history using the configured history_kind" do
      h = History.new(path: hist_path)
      f = InputField.new(
        prompt: prompt("> "),
        history: h,
        history_kind: :search_string,
      )

      f.act_on(:insert, "needle")
      f.act_on(:accept_line)

      expect(h.entries.map(&:text)).to eq(["needle"])
      expect(h.entries.map(&:kind)).to eq([:search_string])
    end

    it "accept_line adds history context from history_ctx" do
      h = History.new(path: hist_path)
      f = InputField.new(
        prompt: prompt("> "),
        history: h,
        history_ctx: -> { { session: "pager_search" } },
      )

      f.act_on(:insert, "needle")
      f.act_on(:accept_line)

      expect(h.entries.last.ctx).to eq("session" => "pager_search")
    end

    it "act_on falls back to calling buffer methods when the action isn't registered" do
      FatTerm::Actions.reset!  # simulate minimal load / no registration

      buf = FatTerm::InputBuffer.new
      field = FatTerm::InputField.new(buffer: buf, prompt: prompt('hello $ '))

      field.act_on(:insert, "xxxxx")
      expect(buf.text).to eq("xxxxx")
    end

    it "act_on raises ActionError when neither registry nor target responds" do
      FatTerm::Actions.reset!

      buf = FatTerm::InputBuffer.new
      field = FatTerm::InputField.new(buffer: buf, prompt: prompt('hello $ '))

      expect {
        field.act_on(:definitely_not_real)
      }.to raise_error(FatTerm::ActionError, /Unknown action: definitely_not_real/i)
    end

    it "history_prev replaces buffer with previous entry" do
      h = History.new(path: hist_path)
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "")

      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("two")
    end

    it "history_next returns toward scratch, then empty when done" do
      h = History.new(path: hist_path)
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "")

      f.act_on(:history_prev) # -> "two"
      f.act_on(:history_prev) # -> "one"

      f.act_on(:history_next) # -> "two"
      expect(f.buffer.text).to eq("two")

      f.act_on(:history_next) # -> scratch ("typing")
      expect(f.buffer.text).to eq("")

      f.act_on(:history_next) # -> ""
      expect(f.buffer.text).to eq("")
    end

    it "history actions use a proc-valued history_kind" do
      h = History.new(path: hist_path)
      regex = false

      f = InputField.new(
        prompt: prompt("> "),
        history: h,
        history_kind: -> { regex ? :search_regex : :search_string },
      )

      f.act_on(:insert, "plain")
      f.act_on(:accept_line)

      regex = true
      f.act_on(:insert, "re.*")
      f.act_on(:accept_line)

      expect(h.entries.map(&:text)).to eq(["plain", "re.*"])
      expect(h.entries.map(&:kind)).to eq([:search_string, :search_regex])
    end

    it "history_prev and history_next use the configured history_kind" do
      h = History.new(path: hist_path)
      h.add("cmd1", kind: :command)
      h.add("search1", kind: :search_string)
      h.add("cmd2", kind: :command)
      h.add("search2", kind: :search_string)

      f = InputField.new(
        prompt: prompt("> "),
        history: h,
        history_kind: :search_string,
      )

      f.act_on(:insert, "sear")

      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("search2")

      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("search1")

      f.act_on(:history_next)
      expect(f.buffer.text).to eq("search2")

      f.act_on(:history_next)
      expect(f.buffer.text).to eq("sear")
    end

    it "history actions are no-ops when no history object is provided" do
      f = InputField.new(prompt: prompt("> "))
      f.act_on(:insert, "typing")

      expect { f.act_on(:history_prev) }.not_to raise_error
      expect { f.act_on(:history_next) }.not_to raise_error
      expect(f.buffer.text).to eq("typing")
    end

    it "dispatches buffer actions and resets history cursor for non-history actions" do
      h = History.new(path: hist_path)
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "")

      # Enter history navigation state
      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("two")

      # Non-history action => history cursor reset
      f.act_on(:move_left)

      # Now history_next behaves as if no active cursor => ""
      f.act_on(:history_next)
      expect(f.buffer.text).to eq("")
    end

    it "paste normalizes newlines to spaces before inserting" do
      f = InputField.new(prompt: prompt("> "))

      f.act_on(:paste, "hello\nworld\n")

      expect(f.buffer.text).to eq("hello world ")
    end

    it "paste normalizes CRLF to spaces before inserting" do
      f = InputField.new(prompt: prompt("> "))

      f.act_on(:paste, "hello\r\nworld")

      expect(f.buffer.text).to eq("hello world")
    end

    it "raises ArgumentError for unknown actions" do
      f = InputField.new(prompt: prompt("> "))
      expect { f.act_on(:no_such_action) }.to raise_error(ActionError)
    end

    describe "completion cycling" do
      around do |example|
        Dir.mktmpdir("fat_term_paths") do |dir|
          @tmpdir = dir
          example.run
        end
      end

      def build_field(text, completion_proc: nil, history: nil)
        buffer = FatTerm::InputBuffer.new
        buffer.replace(text)
        FatTerm::InputField.new(
          prompt: "> ",
          buffer: buffer,
          completion_proc: completion_proc,
          history: history,
          history_kind: :command,
          history_ctx: {},
        )
      end

      it "uses a directory-without-slash token to produce popup path candidates" do
        FileUtils.mkdir_p(File.join(@tmpdir, "src"))
        File.write(File.join(@tmpdir, "src", "alpha.rb"), "x")
        File.write(File.join(@tmpdir, "src", "beta.rb"), "x")

        allow(Dir).to receive(:home).and_return(@tmpdir)

        field = build_field("ls -l ~/src")

        expect(field.popup_completion_query).to eq("~/src")
        expect(field.popup_completion_candidates).to include("~/src/alpha.rb", "~/src/beta.rb")
      end

      it "cycles completion suggestions without changing real buffer text" do
        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
        )

        allow(field).to receive(:path_completion_candidates).and_return(
          [
            "~/Downloads/00_WireInfo.pdf",
            "~/Downloads/01_Notes.txt",
          ],
        )

        expect(field.buffer.text).to eq("cat ~/Downloads/")
        expect(field.autosuggestion).to eq("cat ~/Downloads/00_WireInfo.pdf")

        field.cycle_completion!

        expect(field.buffer.text).to eq("cat ~/Downloads/")
        expect(field.autosuggestion).to eq("cat ~/Downloads/01_Notes.txt")
        expect(field.autosuggestion_suffix).to eq("01_Notes.txt")
      end

      it "wraps around when cycling past the end of the suggestion list" do
        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
        )

        allow(field).to receive(:path_completion_candidates).and_return(
          [
            "~/Downloads/00_WireInfo.pdf",
            "~/Downloads/01_Notes.txt",
          ],
        )

        expect(field.autosuggestion).to eq("cat ~/Downloads/00_WireInfo.pdf")

        field.cycle_completion!
        expect(field.autosuggestion).to eq("cat ~/Downloads/01_Notes.txt")

        field.cycle_completion!
        expect(field.autosuggestion).to eq("cat ~/Downloads/00_WireInfo.pdf")
      end

      it "resets the completion cycle when reset_completion_cycle! is called" do
        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
        )

        allow(field).to receive(:path_completion_candidates).and_return(
          [
            "~/Downloads/00_WireInfo.pdf",
            "~/Downloads/01_Notes.txt",
          ],
        )

        field.cycle_completion!
        expect(field.autosuggestion).to eq("cat ~/Downloads/01_Notes.txt")

        field.reset_completion_cycle!
        expect(field.autosuggestion).to eq("cat ~/Downloads/00_WireInfo.pdf")
      end

      it "prefers completion suggestions over history while cycling is inactive" do
        history = FatTerm::History.new
        history.add("cat ~/Downloads/zz_old.txt", kind: :command, ctx: {})

        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
          history: history,
        )

        allow(field).to receive(:path_completion_candidates).and_return(
          [
            "~/Downloads/00_WireInfo.pdf",
            "~/Downloads/01_Notes.txt",
          ],
        )

        expect(field.autosuggestion).to eq("cat ~/Downloads/00_WireInfo.pdf")
      end

      it "syncs virtual suffix to the currently cycled suggestion" do
        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
        )

        allow(field).to receive(:path_completion_candidates).and_return(
          [
            "~/Downloads/00_WireInfo.pdf",
            "~/Downloads/01_Notes.txt",
          ],
        )

        field.cycle_completion!
        field.sync_virtual_suffix!

        expect(field.buffer.text).to eq("cat ~/Downloads/")
        expect(field.buffer.virtual_suffix).to eq("01_Notes.txt")
      end

      it "returns nil autosuggestion when there are no completion or history suggestions" do
        field = build_field(
          "cat ~/Downloads/",
          completion_proc: ->(_buffer) { [] },
        )

        allow(field).to receive(:path_completion_candidates).and_return([])

        expect(field.autosuggestion).to be_nil
        expect(field.autosuggestion_visible?).to be_falsey
        expect(field.autosuggestion_suffix).to eq("")
      end

      it "detects a ~/ path prefix before point" do
        field = build_field("cat ~/Down")
        allow(Dir).to receive(:home).and_return(@tmpdir)

        expect(field.path_completion_prefix).to eq("~/Down")
      end

      it "prefers path autosuggestion over history autosuggestion" do
        FileUtils.mkdir_p(File.join(@tmpdir, "Downloads"))
        File.write(File.join(@tmpdir, "Downloads", "report.pdf"), "x")

        history = FatTerm::History.new
        history.add("cat ~/Downloads/zzz", kind: :command, ctx: {})

        buffer = FatTerm::InputBuffer.new
        buffer.replace("cat ~/Downloads/")

        field = FatTerm::InputField.new(
          prompt: "> ",
          buffer: buffer,
          history: history,
          history_kind: :command,
          history_ctx: {},
        )

        allow(Dir).to receive(:home).and_return(@tmpdir)

        expect(field.autosuggestion).to eq("cat ~/Downloads/report.pdf")
      end

      it "escapes spaces in path completion candidates" do
        FileUtils.mkdir_p(File.join(@tmpdir, "My Dir"))
        File.write(File.join(@tmpdir, "My Dir", "file name.txt"), "x")

        allow(Dir).to receive(:home).and_return(@tmpdir)

        field = build_field("cat ~/My\\ Dir/")

        candidates = field.path_completion_candidates

        expect(candidates).to include("~/My\\ Dir/file\\ name.txt")
      end

      it "does not treat unescaped spaces as part of a path token" do
        FileUtils.mkdir_p(File.join(@tmpdir, "My Dir"))
        allow(Dir).to receive(:home).and_return(@tmpdir)

        field = build_field("cat ~/My Dir/")

        expect(field.path_completion_candidates).to eq([])
      end
    end
  end
end
