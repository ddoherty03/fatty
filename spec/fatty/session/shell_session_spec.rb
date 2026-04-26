# frozen_string_literal: true

require "tmpdir"
require "ostruct"
require "fileutils"
require "spec_helper"

RSpec.describe Fatty::ShellSession do
  describe "#handle_action" do
    it "builds a history popup with a callable source for :history_search" do
      Dir.mktmpdir do |dir|
        history_path = File.join(dir, "history.jsonl")
        session = Fatty::ShellSession.new(history_path: history_path)
        history = session.history

        history.add("ls", kind: :command)
        history.add("needle", kind: :search_string)
        history.add("pwd", kind: :command)

        commands = session.send(
          :handle_action,
          :history_search,
          [],
          event: nil,
        )
        expect(commands.length).to eq(1)
        expect(commands.first[0]).to eq(:terminal)
        expect(commands.first[1]).to eq(:push_modal)

        popup = commands.first[2]
        expect(popup).to be_a(Fatty::PopUpSession)
        expect(popup.send(:call_source, nil)).to eq(%w[ls pwd])
      end
    end

    it "opens a popup instead of applying a single directory completion for a path without a trailing slash" do
      Dir.mktmpdir("fatty_popup") do |dir|
        FileUtils.mkdir_p(File.join(dir, "src"))
        File.write(File.join(dir, "src", "alpha.rb"), "x")
        File.write(File.join(dir, "src", "beta.rb"), "x")
        allow(Dir).to receive(:home).and_return(dir)

        session = Fatty::ShellSession.new
        buffer = session.field.buffer
        buffer.replace("ls -l ~/src")

        commands = session.send(
          :handle_action,
          :completion_popup,
          [],
          event: nil,
        )

        expect(buffer.text).to eq("ls -l ~/src")
        expect(commands.length).to eq(1)
        expect(commands.first[0]).to eq(:terminal)
        expect(commands.first[1]).to eq(:push_modal)

        popup = commands.first[2]
        expect(popup).to be_a(Fatty::PopUpSession)
        expect(popup.instance_variable_get(:@kind)).to eq(:completion)
        expect(popup.instance_variable_get(:@field).buffer.text).to eq("~/src")

        expect(Array(popup.instance_variable_get(:@source))).to include("~/src/alpha.rb", "~/src/beta.rb")
      end
    end
  end

  describe "#update_cmd" do
    it "handles :paste by inserting normalized text into the field" do
      session = Fatty::ShellSession.new

      commands = session.update([:cmd, :paste, { text: "hello\nworld\n" }])

      expect(commands).to eq([])
      expect(session.field.buffer.text).to eq("hello world ")
    end
  end

  describe "completion" do
    it "cycles the visible autosuggestion without changing real buffer text" do
      session = Fatty::ShellSession.new
      session.field.buffer.replace("git st")

      allow(session.field).to receive(:completion_suggestions).and_return(
                                ["git status", "git stash"]
                              )

      env = session.action_env(event: nil)

      commands = session.send(:apply_action, :complete, [], nil, env: env)

      expect(commands).to eq([])
      expect(session.field.buffer.text).to eq("git st")
      expect(session.field.autosuggestion).to eq("git stash")
      expect(session.field.buffer.virtual_suffix).to eq("ash")
    end

    it "seeds completion popup from the prefix before point, not text after point" do
      completion_proc = lambda do |_buffer|
        %w[cd clear echo exit help history ls pwd theme]
      end

      session = Fatty::ShellSession.new(completion_proc: completion_proc)
      buffer = session.field.buffer

      buffer.text.replace("e four score and seven")
      buffer.cursor = 0

      commands = session.send(
        :handle_action,
        :completion_popup,
        [],
        event: nil,
      )

      expect(commands.length).to eq(1)
      expect(commands.first[0]).to eq(:terminal)
      expect(commands.first[1]).to eq(:push_modal)

      popup = commands.first[2]
      expect(popup).to be_a(Fatty::PopUpSession)
      expect(popup.instance_variable_get(:@kind)).to eq(:completion)
      expect(popup.instance_variable_get(:@field).buffer.text).to eq("")
    end

    it "seeds completion popup from the prefix before point when point is at end of a prefix" do
      completion_proc = lambda do |_buffer|
        %w[cd clear echo exit help history ls less ln pwd theme]
      end
      session = Fatty::ShellSession.new(completion_proc: completion_proc)
      buffer = session.field.buffer

      buffer.text.replace("l four score and seven")
      buffer.cursor = 1

      commands = session.send(
        :handle_action,
        :completion_popup,
        [],
        event: nil,
      )

      expect(commands.length).to eq(1)
      expect(commands.first[0]).to eq(:terminal)
      expect(commands.first[1]).to eq(:push_modal)

      popup = commands.first[2]
      expect(popup).to be_a(Fatty::PopUpSession)
      expect(popup.instance_variable_get(:@kind)).to eq(:completion)
      expect(popup.instance_variable_get(:@field).buffer.text).to eq("l")
    end
  end
end
