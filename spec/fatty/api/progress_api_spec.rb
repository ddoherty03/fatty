# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe ProgressApi do
    let(:terminal) do
      instance_double(
        Fatty::Terminal,
        apply_command: nil,
        render_frame: nil,
      )
    end
    let(:env) do
      Fatty::CallbackEnvironment.new(
        terminal: terminal,
        output_id: :output,
      )
    end
    let(:applied_commands) { [] }
    let(:terminal) do
      instance_double(
        Fatty::Terminal,
        render_frame: nil,
        screen: nil,
      )
    end

    before do
      allow(terminal).to receive(:apply_command) do |command|
        applied_commands << command
      end
      allow(terminal).to receive(:without_cursor_restore).and_yield
    end

    describe "#add_progress" do
      it "creates and returns a Progress object" do
        progress = env.add_progress(label: "Importing", total: 10)

        expect(progress).to be_a(Fatty::Progress)
      end

      it "stores the progress object on the environment" do
        progress = env.add_progress(label: "Importing", total: 10)

        expect(env.progress).to be(progress)
      end

      it "initializes progress with the supplied attributes" do
        progress = env.add_progress(
          label: "Downloading",
          total: 20,
          style: :bar,
          role: :good,
          width: 12,
        )

        expect(progress.label).to eq("Downloading")
        expect(progress.total).to eq(20)
        expect(progress.style).to eq(:bar)
        expect(progress.role).to eq(:good)
        expect(progress.width).to eq(12)
      end

      it "refreshes status immediately when progress is created" do
        env.add_progress(label: "Importing", style: :count_percent, total: 10, role: :info)

        expect(terminal).to have_received(:apply_command) do |command|
          expect(command.target).to eq(:status)
          expect(command.action).to eq(:show)
          expect(command.payload.fetch(:text)).to match(/\AImporting \[0\/10\] 0%/)
          expect(command.payload.fetch(:role)).to eq(:info)
        end
      end

      it "does not queue commands on the callback environment" do
        env.add_progress(label: "Importing", total: 10)

        expect(env.commands).to eq([])
      end

      it "allows spinner progress without a total" do
        progress = env.add_progress(label: "Waiting", style: :spinner)

        expect(progress.total).to be_nil
        expect(progress.style).to eq(:spinner)
      end

      it "raises for non-spinner progress without a total" do
        expect {
          env.add_progress(label: "Importing", style: :percent)
        }.to raise_error(ArgumentError, /positive integer total/)
      end
    end

    describe "created progress object" do
      it "updates status immediately" do
        progress = env.add_progress(label: "Importing", style: :count_percent, total: 10)

        progress.update(current: 5)

        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to match(/Importing \[5\/10\] 50%/)
      end

      it "renders the frame when update render is true" do
        progress = env.add_progress(label: "Importing", total: 10)
        progress.update(current: 5, render: true)
        expect(terminal).to have_received(:render_frame)
      end

      it "finishes by showing a final status message" do
        progress = env.add_progress(label: "Importing", total: 10)

        progress.finish("Complete")
        command = applied_commands.last

        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to match(/Complete/)
      end

      it "clears status when finished with clear" do
        progress = env.add_progress(label: "Importing", total: 10)
        progress.finish(clear: true)
        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:clear)
      end

      it "clears status directly" do
        progress = env.add_progress(label: "Importing", total: 10)
        progress.clear

        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:clear)
      end
    end
  end
end
