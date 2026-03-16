# frozen_string_literal: true

require "tmpdir"
require "ostruct"
require "spec_helper"

RSpec.describe FatTerm::ShellSession do
  describe "#handle_action" do
    it "builds a history popup with a callable source for :history_search" do
      Dir.mktmpdir do |dir|
        history_path = File.join(dir, "history.jsonl")
        history = FatTerm::History.new(path: history_path)

        allow(FatTerm::History).to receive(:new).and_return(history)

        session = FatTerm::ShellSession.new

        history.add("ls", kind: :command)
        history.add("needle", kind: :search_string)
        history.add("pwd", kind: :command)

        commands = session.send(
          :handle_action,
          :history_search,
          [],
          terminal: instance_double(FatTerm::Terminal),
          event: nil,
        )
        expect(commands.length).to eq(1)
        expect(commands.first[0]).to eq(:terminal)
        expect(commands.first[1]).to eq(:push_modal)

        popup = commands.first[2]
        expect(popup).to be_a(FatTerm::PopUpSession)
        expect(popup.send(:call_source, nil)).to eq(%w[ls pwd])
      end
    end
  end

  describe "#update_cmd" do
    it "handles :paste by inserting normalized text into the field" do
      session = FatTerm::ShellSession.new

      commands = session.update(
        [:cmd, :paste, { text: "hello\nworld\n" }],
        terminal: instance_double(FatTerm::Terminal),
      )

      expect(commands).to eq([])
      expect(session.field.buffer.text).to eq("hello world ")
    end
  end

  describe "completion" do
    it "seeds completion popup from the prefix before point, not text after point" do
      completion_proc = lambda do |_buffer|
        %w[cd clear echo exit help history ls pwd theme]
      end

      session = FatTerm::ShellSession.new(completion_proc: completion_proc)
      buffer = session.field.buffer

      buffer.text.replace("e four score and seven")
      buffer.cursor = 0

      commands = session.send(
        :handle_action,
        :complete,
        [],
        terminal: instance_double(FatTerm::Terminal),
        event: nil,
      )

      expect(commands.length).to eq(1)
      expect(commands.first[0]).to eq(:terminal)
      expect(commands.first[1]).to eq(:push_modal)

      popup = commands.first[2]
      expect(popup).to be_a(FatTerm::PopUpSession)
      expect(popup.instance_variable_get(:@kind)).to eq(:completion)
      expect(popup.instance_variable_get(:@field).buffer.text).to eq("")
    end

    it "seeds completion popup from the prefix before point when point is at end of a prefix" do
      completion_proc = lambda do |_buffer|
        %w[cd clear echo exit help history ls less ln pwd theme]
      end
      session = FatTerm::ShellSession.new(completion_proc: completion_proc)
      buffer = session.field.buffer

      buffer.text.replace("l four score and seven")
      buffer.cursor = 1

      commands = session.send(
        :handle_action,
        :complete,
        [],
        terminal: instance_double(FatTerm::Terminal),
        event: nil,
      )

      expect(commands.length).to eq(1)
      expect(commands.first[0]).to eq(:terminal)
      expect(commands.first[1]).to eq(:push_modal)

      popup = commands.first[2]
      expect(popup).to be_a(FatTerm::PopUpSession)
      expect(popup.instance_variable_get(:@kind)).to eq(:completion)
      expect(popup.instance_variable_get(:@field).buffer.text).to eq("l")
    end
  end
end
