# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Fatty
  RSpec.describe InputField do
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
  end
end
