# frozen_string_literal: true

require "spec_helper"

RSpec.describe FatTerm::ModalSession do
  class TestModalSession < FatTerm::ModalSession
    def initialize
      super(keymap: FatTerm::Keymaps.emacs, views: [])
    end

    def geometry(cols:, rows:)
      [20, 6]
    end
  end

  let(:session) { TestModalSession.new }

  describe "#geometry" do
    it "raises NotImplementedError in the base class" do
      base = FatTerm::ModalSession.new(keymap: FatTerm::Keymaps.emacs, views: [])

      expect {
        base.geometry(cols: 80, rows: 24)
      }.to raise_error(NotImplementedError, /must implement #geometry/)
    end
  end

  describe "#handle_resize" do
    it "calls #rebuild_windows! and returns an empty message list" do
      allow(session).to receive(:rebuild_windows!).and_return(nil)

      result = session.handle_resize

      expect(result).to eq([])
      expect(session).to have_received(:rebuild_windows!)
    end
  end

  describe "#rebuild_windows!" do
    let(:old_win) { instance_double("Curses::Window") }
    let(:new_win) { instance_double("Curses::Window") }

    before do
      stub_const("Curses", Module.new) unless defined?(Curses)
      allow(::Curses).to receive(:cols).and_return(80)
      allow(::Curses).to receive(:lines).and_return(24)
      stub_const("Curses::Window", Class.new) unless defined?(Curses::Window)
      allow(::Curses::Window).to receive(:new).and_return(new_win)
    end

    it "creates a centered window using #geometry" do
      session.rebuild_windows!

      expect(::Curses::Window).to have_received(:new).with(6, 20, 9, 30)
      expect(session.win).to eq(new_win)
    end

    it "clears #win before closing the old window" do
      session.instance_variable_set(:@win, old_win)

      allow(session).to receive(:safely_close_window) do |win|
        expect(win).to eq(old_win)
        expect(session.win).to be_nil
      end

      session.rebuild_windows!

      expect(session).to have_received(:safely_close_window).with(old_win)
      expect(session.win).to eq(new_win)
    end
  end

  describe "#close" do
    let(:old_win) { instance_double("Curses::Window") }

    it "clears #win and safely closes the existing window" do
      session.instance_variable_set(:@win, old_win)

      allow(session).to receive(:safely_close_window) do |win|
        expect(win).to eq(old_win)
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

  describe "geometry helpers" do
    describe "#max_width" do
      it "subtracts both margins and honors the minimum width" do
        expect(session.send(:max_width, cols: 80, margin: 2, min_width: 10)).to eq(76)
        expect(session.send(:max_width, cols: 8, margin: 4, min_width: 10)).to eq(10)
      end
    end

    describe "#max_height" do
      it "subtracts both margins and honors the minimum height" do
        expect(session.send(:max_height, rows: 24, margin: 2, min_height: 5)).to eq(20)
        expect(session.send(:max_height, rows: 6, margin: 4, min_height: 5)).to eq(5)
      end
    end

    describe "#clamp_width" do
      it "clamps to max_width when no hard max is given" do
        expect(session.send(:clamp_width, 90, max_width: 70)).to eq(70)
        expect(session.send(:clamp_width, 60, max_width: 70)).to eq(60)
      end

      it "also clamps to hard_max when given" do
        expect(session.send(:clamp_width, 90, max_width: 100, hard_max: 80)).to eq(80)
        expect(session.send(:clamp_width, 70, max_width: 100, hard_max: 80)).to eq(70)
      end
    end

    describe "#clamp_height" do
      it "clamps between min_height and max_height" do
        expect(session.send(:clamp_height, 10, max_height: 20, min_height: 5)).to eq(10)
        expect(session.send(:clamp_height, 3, max_height: 20, min_height: 5)).to eq(5)
        expect(session.send(:clamp_height, 30, max_height: 20, min_height: 5)).to eq(20)
      end
    end
  end
end
