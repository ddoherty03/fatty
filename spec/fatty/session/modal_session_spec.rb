# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe ModalSession do
    class TestModalSession < Fatty::ModalSession
      def initialize
        super(keymap: Fatty::Keymaps.emacs)
      end

      def geometry(cols:, rows:)
        [20, 6]
      end
    end

    let(:session) { TestModalSession.new }
    let(:input_rect) do
      instance_double(
        Fatty::Screen::Rect,
        row: 22,
        col: 0,
        rows: 1,
        cols: 80,
      )
    end

    let(:screen) do
      instance_double(
        Fatty::Screen,
        rows: 24,
        cols: 80,
        input_rect: input_rect,
      )
    end

    let(:renderer) do
      instance_double(
        Fatty::Renderer,
        screen: screen,
      )
    end

    let(:terminal) do
      instance_double(
        Fatty::Terminal,
        renderer: renderer,
      )
    end

    before do
      session.init(terminal: terminal)
    end

    describe "#geometry" do
      it "raises NotImplementedError in the base class" do
        base = Fatty::ModalSession.new(keymap: Fatty::Keymaps.emacs)

        expect {
          base.send(:geometry, cols: 80, rows: 24)
        }.to raise_error(NotImplementedError, /must implement #geometry/)
      end
    end

    describe "#handle_resize" do
      it "rebuilds windows and returns no commands" do
        allow(session).to receive(:rebuild_windows!).and_return(nil)

        result = session.send(:handle_resize)

        expect(result).to eq([])
        expect(session).to have_received(:rebuild_windows!)
      end

      it "is public session protocol" do
        session = Fatty::PopUpSession.new(
          source: ["one", "two"],
          kind: :terminal_choose,
          title: "Choose",
          message: "Pick one",
        )
        expect(session).to respond_to(:handle_resize)
      end
    end

    describe "#rebuild_windows!" do
      let(:old_win) { instance_double(::Curses::Window) }
      let(:new_win) { instance_double(::Curses::Window) }

      before do
        allow(::Curses).to receive(:cols).and_return(80)
        allow(::Curses).to receive(:lines).and_return(24)
        allow(::Curses::Window).to receive(:new).and_return(new_win)
      end

      it "creates a centered window using geometry" do
        session.send(:rebuild_windows!)

        expect(::Curses::Window).to have_received(:new).with(6, 20, 9, 30)
        expect(session.win).to be(new_win)
      end

      it "clears win before closing the old window" do
        session.instance_variable_set(:@win, old_win)

        allow(session).to receive(:safely_close_window) do |win|
          expect(win).to be(old_win)
          expect(session.win).to be_nil
        end

        session.send(:rebuild_windows!)

        expect(session).to have_received(:safely_close_window).with(old_win)
        expect(session.win).to be(new_win)
      end
    end

    describe "#close" do
      let(:old_win) { instance_double(::Curses::Window) }

      it "clears win and safely closes the existing window" do
        session.instance_variable_set(:@win, old_win)

        allow(session).to receive(:safely_close_window) do |win|
          expect(win).to be(old_win)
          expect(session.win).to be_nil
        end

        result = session.close

        expect(result).to be_nil
        expect(session).to have_received(:safely_close_window).with(old_win)
        expect(session.win).to be_nil
      end

      it "safely closes nil when no window is present" do
        allow(session).to receive(:safely_close_window)

        result = session.close

        expect(result).to be_nil
        expect(session).to have_received(:safely_close_window).with(nil)
        expect(session.win).to be_nil
      end
    end

    describe "#safely_close_window" do
      it "erases, refreshes, and closes the window" do
        win = instance_double(
          ::Curses::Window,
          erase: nil,
          noutrefresh: nil,
          close: nil,
        )

        result = session.send(:safely_close_window, win)

        expect(result).to be_nil
        expect(win).to have_received(:erase)
        expect(win).to have_received(:noutrefresh)
        expect(win).to have_received(:close)
      end

      it "does nothing for nil" do
        expect(session.send(:safely_close_window, nil)).to be_nil
      end

      it "ignores already-closed window errors" do
        win = instance_double(::Curses::Window)

        allow(win).to receive(:erase).and_raise(RuntimeError, "closed window")
        allow(win).to receive(:noutrefresh).and_raise(RuntimeError, "already closed window")
        allow(win).to receive(:close).and_raise(RuntimeError, "closed window")

        expect {
          session.send(:safely_close_window, win)
        }.not_to raise_error
      end

      it "reraises unrelated runtime errors" do
        win = instance_double(::Curses::Window)

        allow(win).to receive(:erase).and_raise(RuntimeError, "boom")

        expect {
          session.send(:safely_close_window, win)
        }.to raise_error(RuntimeError, "boom")
      end
    end

    describe "geometry helpers" do
      it "computes maximum width" do
        expect(session.send(:max_width, cols: 80, margin: 2, min_width: 10)).to eq(76)
        expect(session.send(:max_width, cols: 8, margin: 4, min_width: 10)).to eq(10)
      end

      it "computes maximum height" do
        expect(session.send(:max_height, rows: 24, margin: 2, min_height: 5)).to eq(20)
        expect(session.send(:max_height, rows: 6, margin: 4, min_height: 5)).to eq(5)
      end

      it "clamps width" do
        expect(session.send(:clamp_width, 90, max_width: 70)).to eq(70)
        expect(session.send(:clamp_width, 60, max_width: 70)).to eq(60)
      end

      it "clamps width to hard max" do
        expect(session.send(:clamp_width, 90, max_width: 100, hard_max: 80)).to eq(80)
        expect(session.send(:clamp_width, 70, max_width: 100, hard_max: 80)).to eq(70)
      end

      it "clamps height" do
        expect(session.send(:clamp_height, 10, max_height: 20, min_height: 5)).to eq(10)
        expect(session.send(:clamp_height, 3, max_height: 20, min_height: 5)).to eq(5)
        expect(session.send(:clamp_height, 30, max_height: 20, min_height: 5)).to eq(20)
      end
    end
  end
end
