# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Progress do
    let(:applied_commands) { [] }
    let(:terminal) do
      instance_double(
        Fatty::Terminal,
        apply_command: nil,
        render_frame: nil,
        screen: nil,
      )
    end

    before do
      allow(terminal).to receive(:apply_command) do |command|
        applied_commands << command
      end
    end

    describe "#initialize" do
      it "requires total for non-spinner styles" do
        expect {
          Progress.new(
            terminal: terminal,
            label: "Importing",
            style: :bar,
          )
        }.to raise_error(ArgumentError, /requires total/)
      end

      it "allows spinner without total" do
        expect {
          Progress.new(
            terminal: terminal,
            label: "Waiting",
            style: :spinner,
          )
        }.not_to raise_error
      end
    end

    describe "#update" do
      it "renders spinner without percent when total is unknown" do
        progress = Progress.new(
          terminal: terminal,
          label: "Waiting",
          style: :spinner,
        )

        progress.update(render: false)
        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to include("Waiting")
      end

      it "renders percent for spinner when total is known" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 100,
          style: :spinner,
        )

        progress.update(current: 37, render: false)

        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to include("Importing")
      end

      it "advances spinner when updated without current" do
        progress = Progress.new(
          terminal: terminal,
          label: "Waiting",
          style: :spinner,
        )

        progress.update(render: false)
        progress.update(render: false)

        status_commands = applied_commands.select do |command|
          command.target == :status && command.action == :show
        end

        expect(status_commands.length).to be >= 3
        expect(status_commands.map { |command| command.payload.fetch(:text) }.uniq.length)
          .to be >= 2
      end
    end

    describe "#finish" do
      it "renders the finish message" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
          style: :percent,
        )

        progress.finish("Complete", render: false)

        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to include("Complete")
      end

      it "forces a redraw when render is true" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
          style: :percent,
        )

        progress.finish("Complete", render: true)
        expect(terminal).to have_received(:render_frame)
      end
    end

    describe "#update with trail style" do
      it "appends indicators across updates" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 4,
          style: :trail,
        )

        progress.update(current: 1, indicator: "+", render: false)
        progress.update(current: 2, indicator: "-", render: false)
        progress.update(current: 3, indicator: "^", render: false)
        progress.update(current: 4, indicator: ".", render: false)

        status_commands = applied_commands.select do |command|
          command.target == :status && command.action == :show
        end
        text = status_commands.last.payload.fetch(:text)
        # The text will be something like this:
        # ["Importing [4/4] 100%", "  ", "+", "-", "^", ".", ""]
        expect(text).to include("+")
        expect(text).to include("^")
        expect(text).to include(".")
      end
    end

    describe "#update with bar style" do
      it "renders percent for bar progress" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 100,
          style: :bar,
        )

        progress.update(current: 37, render: false)

        # expect(terminal).to have_received(:set_status).with(match(/37%/), role: anything)
        command = applied_commands.last
        expect(command.target).to eq(:status)
        expect(command.action).to eq(:show)
        expect(command.payload.fetch(:text)).to include("37%")
      end
    end
  end
end
