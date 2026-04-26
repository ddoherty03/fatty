# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Terminal::Progress do
    let(:terminal) do
      instance_double(
        Fatty::Terminal,
        set_status: nil,
        render_now: nil,
        screen: nil,
      )
    end

    describe "#initialize" do
      it "requires total for non-spinner styles" do
        expect {
          Fatty::Terminal::Progress.new(
            terminal: terminal,
            label: "Importing",
            style: :bar,
          )
        }.to raise_error(ArgumentError, /requires total/)
      end

      it "allows spinner without total" do
        expect {
          Fatty::Terminal::Progress.new(
            terminal: terminal,
            label: "Waiting",
            style: :spinner,
          )
        }.not_to raise_error
      end
    end

    describe "#update" do
      it "renders spinner without percent when total is unknown" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Waiting",
          style: :spinner,
        )

        progress.update(render: false)

        expect(terminal).to have_received(:set_status)
                              .with(match(/\AWaiting /), role: :status_info).at_least(:once)

        expect(terminal).not_to have_received(:set_status)
                                  .with(match(/%/), role: :status_info)
      end

      it "renders percent for spinner when total is known" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 100,
          style: :spinner,
        )

        progress.update(current: 37, render: false)

        expect(terminal).to have_received(:set_status).with(match(/37%/), role: anything)
      end

      it "advances spinner when updated without current" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Waiting",
          style: :spinner,
        )

        progress.update(render: false)
        progress.update(render: false)

        expect(terminal).to have_received(:set_status).at_least(:twice)
      end
    end

    describe "#finish" do
      it "renders the finish message" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
          style: :percent,
        )

        progress.finish("Complete", render: false)

        expect(terminal)
          .to have_received(:set_status)
                .with(match(/Complete/), role: :status_info, transient: true)
      end

      it "forces a redraw when render is true" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 10,
          style: :percent,
        )

        progress.finish("Complete", render: true)

        expect(terminal).to have_received(:render_now)
      end
    end

    describe "#update with trail style" do
      it "appends indicators across updates" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 4,
          style: :trail,
        )

        progress.update(current: 1, indicator: "+", render: false)
        progress.update(current: 2, indicator: "-", render: false)
        progress.update(current: 3, indicator: "^", render: false)
        progress.update(current: 4, indicator: ".", render: false)

        expect(terminal).to have_received(:set_status).with(match(/\+\-\^\./), role: anything)
      end
    end

    describe "#update with bar style" do
      it "renders percent for bar progress" do
        progress = Fatty::Terminal::Progress.new(
          terminal: terminal,
          label: "Importing",
          total: 100,
          style: :bar,
        )

        progress.update(current: 37, render: false)

        expect(terminal).to have_received(:set_status).with(match(/37%/), role: anything)
      end
    end
  end
end
