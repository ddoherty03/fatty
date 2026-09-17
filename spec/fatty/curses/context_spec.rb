# frozen_string_literal: true

module Fatty
  module Curses
    RSpec.describe Context do
      describe "#close" do
        it "restores normal terminal modes before closing curses" do
          context = Fatty::Curses::Context.new
          context.instance_variable_set(:@started, true)
          allow(context).to receive(:close_windows)
          allow(context).to receive(:disable_bracketed_paste!)
          allow(::Curses).to receive(:curs_set)
          allow(::Curses).to receive(:noraw)
          allow(::Curses).to receive(:echo)
          allow(::Curses).to receive(:nl)
          allow(::Curses).to receive(:close_screen)

          context.close

          expect(::Curses).to have_received(:curs_set).with(1)
          expect(::Curses).to have_received(:noraw)
          expect(::Curses).to have_received(:echo)
          expect(::Curses).to have_received(:nl)
          expect(::Curses).to have_received(:close_screen)
          expect(context).not_to be_started
        end
      end

      describe "#suspend" do
        it "saves curses program mode and returns the terminal to shell mode" do
          context = Fatty::Curses::Context.new
          context.instance_variable_set(:@started, true)

          allow(context).to receive(:disable_bracketed_paste!)
          allow(::Curses).to receive(:def_prog_mode)
          allow(::Curses).to receive(:curs_set)
          allow(Fatty::Curses::Native).to receive(:endwin)

          context.suspend

          expect(::Curses).to have_received(:def_prog_mode)
          expect(context).to have_received(:disable_bracketed_paste!)
          expect(::Curses).to have_received(:curs_set).with(1)
          expect(Fatty::Curses::Native).to have_received(:endwin)
        end
      end

      describe "#resume" do
        it "restores curses and bracketed paste mode" do
          context = Fatty::Curses::Context.new
          context.instance_variable_set(:@started, true)

          allow(context).to receive(:enable_bracketed_paste!)
          allow(::Curses).to receive(:reset_prog_mode)
          allow(::Curses).to receive(:refresh)

          context.resume

          expect(::Curses).to have_received(:reset_prog_mode).ordered
          expect(::Curses).to have_received(:refresh).ordered
          expect(context).to have_received(:enable_bracketed_paste!)
        end
      end
    end
  end
end
