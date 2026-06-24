# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe AlertApi do
    let(:applied_commands) { [] }

    let(:terminal) do
      instance_double(Fatty::Terminal)
    end

    let(:env) do
      Fatty::CallbackEnvironment.new(
        terminal: terminal,
        output_id: :output,
      )
    end

    before do
      allow(terminal).to receive(:apply_command) do |command|
        applied_commands << command
      end
    end

    describe "#alert" do
      it "applies an alert command immediately and returns nil" do
        result = env.alert("Careful", role: :warn)

        expect(result).to be_nil
        expect(env.commands).to eq([])
        expect(applied_commands.length).to eq(1)
        expect(applied_commands.first.target).to eq(:alert)
        expect(applied_commands.first.action).to eq(:show)
        expect(applied_commands.first.payload).to eq(text: "Careful", role: :warn)
      end

      it "defaults to info role" do
        env.alert("Hello")

        expect(applied_commands.first.payload).to eq(text: "Hello", role: :info)
      end
    end
  end
end
