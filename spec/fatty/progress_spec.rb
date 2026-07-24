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
      allow(terminal).to receive(:without_cursor_restore).and_yield
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
        }.to raise_error(ArgumentError, /requires a positive integer total/)
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

      it "uses defaults for blank optional values" do
        progress = Progress.new(
          terminal: terminal,
          label: nil,
          total: 10,
          style: nil,
          role: nil,
          width: nil,
        )

        expect(progress.label).to eq("Progress")
        expect(progress.style).to eq(:percent)
        expect(progress.role).to eq(:info)
        expect(progress.width).to eq(40)
      end

      it "rejects an unknown style" do
        expect {
          Progress.new(
            terminal: terminal,
            label: "Importing",
            total: 10,
            style: :percnet,
          )
        }.to raise_error(ArgumentError, /unknown progress style/)
      end

      it "uses 1 for a malformed total" do
        p = Progress.new(
            terminal: terminal,
            label: "Importing",
            total: "ten",
            style: :percent,
          )
        expect(p.total).to eq(1)
      end

      it "uses the default width for a nonpositive width" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
          style: :bar,
          width: 0,
        )
        expect(progress.width).to eq(40)
      end
    end

    describe "#normalize_total" do
      it "preserves nil" do
        progress = Fatty::Progress.new(terminal: terminal, total: nil, style: :spinner)

        expect(progress.total).to be_nil
      end

      it "normalizes zero to one" do
        progress = Fatty::Progress.new(terminal: terminal, total: 0)

        expect(progress.total).to eq(1)
      end

      it "normalizes negative totals to one" do
        progress = Fatty::Progress.new(terminal: terminal, total: -5)

        expect(progress.total).to eq(1)
      end

      it "normalizes invalid totals to one" do
        progress = Fatty::Progress.new(terminal: terminal, total: "nonsense")

        expect(progress.total).to eq(1)
      end
    end

    describe "#update" do
      it "rejects a malformed current value" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
        )
        expect {
          progress.update(current: "five")
        }.to raise_error(ArgumentError, /current must be an integer/)
      end

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

      it "does not truncate trail indicators" do
        progress = Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 150,
          style: :trail,
        )

        statuses = []
        allow(terminal).to receive(:apply_command) do |command|
          if command.target == :status && command.action == :show
            statuses << command.payload.fetch(:text)
          end
        end

        150.times do |i|
          progress.update(current: i + 1, indicator: ".", render: false)
        end

        text = statuses.last
        rendered =
          if text.is_a?(Array)
            text.map { |part| part.is_a?(Hash) ? part[:text].to_s : part.to_s }.join
          else
            text.to_s
          end

        expect(rendered.count(".")).to eq(150)
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
