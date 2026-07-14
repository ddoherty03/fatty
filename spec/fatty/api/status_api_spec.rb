# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe StatusApi do
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
      allow(terminal).to receive(:without_cursor_restore).and_yield
      allow(terminal).to receive(:render_frame)
    end

    describe "#status" do
      it "applies a status command immediately and returns nil" do
        result = env.status("Working", role: :good)

        expect(result).to be_nil
        expect(env.commands).to eq([])
        expect(applied_commands.length).to eq(1)
        expect(applied_commands.first.target).to eq(:status)
        expect(applied_commands.first.action).to eq(:show)
        expect(applied_commands.first.payload).to eq(text: "Working", role: :good)
      end

      it "renders status immediately by default" do
        result = env.status("Working")

        expect(result).to be_nil
        expect(applied_commands.length).to eq(1)
        expect(applied_commands.first.target).to eq(:status)
        expect(applied_commands.first.action).to eq(:show)
        expect(applied_commands.first.payload).to eq(
                                                    text: "Working",
                                                    role: :info,
                                                  )
        expect(terminal).to have_received(:without_cursor_restore)
        expect(terminal).to have_received(:render_frame)
      end

      it "can defer status rendering" do
        env.status("Working", render: false)

        expect(applied_commands.length).to eq(1)
        expect(terminal).not_to have_received(:without_cursor_restore)
        expect(terminal).not_to have_received(:render_frame)
      end
    end

    describe "role helpers" do
      it "maps info to role info" do
        env.info("Info")

        expect(applied_commands.last.payload).to eq(text: "Info", role: :info)
      end

      it "maps good to role good" do
        env.good("Good")

        expect(applied_commands.last.payload).to eq(text: "Good", role: :good)
      end

      it "maps warn to role warn" do
        env.warn("Warn")

        expect(applied_commands.last.payload).to eq(text: "Warn", role: :warn)
      end

      it "maps oops to role error" do
        env.oops("Oops")

        expect(applied_commands.last.payload).to eq(text: "Oops", role: :error)
      end
    end
  end
end
