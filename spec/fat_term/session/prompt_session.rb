# frozen_string_literal: true

require "tmpdir"
require "fileutils"

require "spec_helper"

module FatTerm
  RSpec.describe PromptSession do
    it "accepts the current text and records it in prompt history" do
      Dir.mktmpdir do |dir|
        history_path = File.join(dir, "history.jsonl")

        session = FatTerm::PromptSession.new(
          initial: "four score and seven years ago",
          history_path: history_path,
          history_ctx: { prompt: "Memo:" },
        )

        commands = session.send(
          :handle_action,
          :accept_line,
          [],
          terminal: instance_double(FatTerm::Terminal),
          event: nil,
        )

        expect(commands).to eq([
          [:terminal, :send_modal_owner, [:cmd, :prompt_result, { kind: nil, text: "four score and seven years ago" }]],
          [:terminal, :pop_modal],
        ])

        expect(session.history.entries.last.text).to eq("four score and seven years ago")
        expect(session.history.entries.last.kind).to eq(:prompt)
        expect(session.history.entries.last.ctx).to eq({ "prompt" => "Memo:" })
      end
    end

    it "stores prompt history under the supplied history context" do
      Dir.mktmpdir do |dir|
        history_path = File.join(dir, "history.jsonl")

        session = FatTerm::PromptSession.new(
          initial: "Checking",
          history_path: history_path,
          history_ctx: { prompt: :account_name },
        )

        session.send(
          :handle_action,
          :accept_line,
          [],
          terminal: instance_double(FatTerm::Terminal),
          event: nil,
        )

        expect(session.history.entries.last.ctx).to eq({ "prompt" => :account_name })
      end
    end
  end
end
