# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Fatty
  RSpec.describe InputField do
    describe "#state" do
      it "returns prompt, text, cursor column, virtual suffix, mark, and selection state" do
        buffer = Fatty::InputBuffer.new
        buffer.replace("hello")
        field = Fatty::InputField.new(prompt: "> ", buffer: buffer)

        expect(field.state)
          .to eq(["> ", "hello", 5, "", false, nil])
      end

      it "includes the synced virtual suffix" do
        buffer = Fatty::InputBuffer.new
        buffer.replace("fo")
        field = Fatty::InputField.new(
          prompt: "> ",
          buffer: buffer,
          completion_proc: ->(_buffer) { ["fold"] },
        )

        field.sync_virtual_suffix!

        expect(field.state)
          .to eq(["> ", "fo", 2, "ld", false, nil])
      end

      it "includes active region state" do
        buffer = Fatty::InputBuffer.new
        buffer.replace("hello")
        field = Fatty::InputField.new(prompt: "> ", buffer: buffer)

        buffer.cursor = 1
        buffer.set_mark
        buffer.cursor = 5

        expect(field.state)
          .to eq(["> ", "hello", 5, "", true, 1...5])
      end
    end

    describe "#to_s" do
      it "returns the buffer text" do
        field = Fatty::InputField.new
        field.buffer.replace("hello")

        expect(field.to_s).to match(/hello/)
      end
    end

    describe "#empty?" do
      it "delegates to the buffer" do
        field = Fatty::InputField.new

        expect(field).to be_empty

        field.buffer.replace("hello")

        expect(field).not_to be_empty
      end
    end

    describe "#act_on" do
      it "returns nil for nil action" do
        field = Fatty::InputField.new

        expect(field.act_on(nil)).to be_nil
      end

      it "dispatches registered field actions without env" do
        field = Fatty::InputField.new
        field.act_on(:insert, "x")
        expect(field.buffer.text).to eq("x")
      end

      it "raises for unknown actions" do
        field = Fatty::InputField.new
        expect { field.act_on(:definitely_unknown) }
          .to raise_error(Fatty::ActionError, "Unknown action: definitely_unknown")
      end
    end

    describe "completion and autosuggestion" do
      let(:tmpdir) { Dir.mktmpdir("fatty_paths") }

      before do
        allow(Dir).to receive(:home).and_return(tmpdir)
      end

      after do
        FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
      end

      def field_with(text, completion_proc: nil, history: nil)
        buffer = Fatty::InputBuffer.new
        buffer.replace(text)
        Fatty::InputField.new(
          prompt: "> ",
          buffer: buffer,
          completion_proc: completion_proc,
          history: history,
          history_kind: :command,
          history_ctx: {},
        )
      end

      it "returns nil autosuggestion when there are no candidates" do
        field = field_with("no-match", completion_proc: ->(_buffer) { [] })
        field.sync_virtual_suffix!
        expect(field.autosuggestion).to be_nil
        expect(field.state[3]).to eq("")
      end

      it "uses completion candidates for autosuggestion" do
        field = field_with(
          "fo",
          completion_proc: ->(_buffer) { ["fold", "format"] },
        )

        expect(field.autosuggestion).to eq("fold")
        field.sync_virtual_suffix!
        expect(field.state[3]).to eq("ld")
      end

      it "cycles completion candidates without changing real buffer text" do
        field = field_with(
          "fo",
          completion_proc: ->(_buffer) { ["fold", "format"] },
        )

        result = field.cycle_completion!

        expect(result).to eq("fold")
        expect(field.buffer.text).to eq("fo")
        expect(field.state[3]).to eq("ld")

        result = field.cycle_completion!

        expect(result).to eq("format")
        expect(field.buffer.text).to eq("fo")
        expect(field.state[3]).to eq("rmat")
      end

      it "wraps completion cycling" do
        field = field_with(
          "fo",
          completion_proc: ->(_buffer) { ["fold", "format"] },
        )

        expect(field.cycle_completion!).to eq("fold")
        expect(field.cycle_completion!).to eq("format")
        expect(field.cycle_completion!).to eq("fold")
      end

      it "resets completion cycling" do
        field = field_with(
          "fo",
          completion_proc: ->(_buffer) { ["fold", "format"] },
        )

        expect(field.cycle_completion!).to eq("fold")
        expect(field.cycle_completion!).to eq("format")

        field.reset_completion_state!

        expect(field.cycle_completion!).to eq("fold")
      end

      it "uses path completions for popup candidates" do
        FileUtils.mkdir_p(File.join(tmpdir, "src"))
        File.write(File.join(tmpdir, "src", "alpha.rb"), "x")
        File.write(File.join(tmpdir, "src", "beta.rb"), "x")
        field = field_with("ls -l ~/src")

        expect(field.popup_completion_query).to eq("~/src")
        expect(field.popup_completion_candidates).to include(
                                                       "~/src/alpha.rb",
                                                       "~/src/beta.rb",
                                                     )
      end

      it "uses the path token as the popup completion range" do
        FileUtils.mkdir_p(File.join(tmpdir, "src"))
        File.write(File.join(tmpdir, "src", "alpha.rb"), "x")
        field = field_with("ls -l ~/src")

        expect(field.popup_completion_range).to eq(6...11)
      end

      it "falls back to full-line popup completions for non-path suggestions" do
        history = Fatty::History.new(path: nil)
        history.add("bundle exec rspec", kind: :command, ctx: {})
        field = field_with("bundle", history: history)

        expect(field.popup_completion_query).to eq("bundle")
        expect(field.popup_completion_range).to eq(0...6)
        expect(field.popup_completion_candidates).to include("bundle exec rspec")
      end

      it "escapes spaces in rendered path popup candidates" do
        FileUtils.mkdir_p(File.join(tmpdir, "My Dir"))
        File.write(File.join(tmpdir, "My Dir", "file name.txt"), "x")
        field = field_with("cat ~/My\\ Dir/")

        expect(field.popup_completion_candidates)
          .to include("~/My\\ Dir/file\\ name.txt")
      end

      it "does not treat unescaped spaces as part of a path token" do
        FileUtils.mkdir_p(File.join(tmpdir, "My Dir"))
        field = field_with("cat ~/My Dir/")

        expect(field.popup_completion_candidates).to eq([])
      end

      it "prefers history autosuggestion over path autosuggestion" do
        FileUtils.mkdir_p(File.join(tmpdir, "Downloads"))
        File.write(File.join(tmpdir, "Downloads", "report.pdf"), "x")
        history = Fatty::History.new(path: nil)
        history.add("cat ~/Downloads/zzz", kind: :command, ctx: {})
        field = field_with("cat ~/Downloads/", history: history)

        expect(field.autosuggestion).to eq("cat ~/Downloads/zzz")
      end
    end

    describe "#cycle_completion!" do
      it "returns nil and clears virtual suffix when there are no candidates" do
        field = Fatty::InputField.new(
          completion_proc: ->(_buffer) { [] },
        )
        field.buffer.replace("zzz")
        field.buffer.virtual_suffix = "old"

        expect(field.cycle_completion!).to be_nil
        expect(field.buffer.virtual_suffix).to eq("")
      end
    end
  end
end
