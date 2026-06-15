# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe KeytestApi do
    let(:terminal) { instance_double(Fatty::Terminal) }

    let(:env) do
      Fatty::CallbackEnvironment.new(
        terminal: terminal,
        output_id: :output,
      )
    end

    describe "#keytest" do
      it "queues keytest modal commands and returns nil" do
        result = env.keytest

        expect(result).to be_nil
        expect(env.commands.length).to eq(2)

        expect(env.commands[0].target).to eq(:terminal)
        expect(env.commands[0].action).to eq(:push_modal)
        expect(env.commands[0].payload.fetch(:session))
          .to be_a(Fatty::KeyTestSession)

        expect(env.commands[1].target).to eq(:alert)
        expect(env.commands[1].action).to eq(:clear)
      end
    end
  end
end
