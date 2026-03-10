# frozen_string_literal: true

require "tmpdir"
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
end
