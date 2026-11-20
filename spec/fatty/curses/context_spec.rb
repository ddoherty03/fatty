# frozen_string_literal: true

module Fatty
  module Curses
    RSpec.describe Context do
      describe "screen initialization" do
        it "uses the standard console buffer for Windows PDCurses and restores the environment" do
          stub_const('RUBY_PLATFORM', 'x64-mingw-ucrt')
          stub_const('Curses::VERSION', 'PDCursesMod 4.5.4')
          original = ENV['PDC_RESTORE_SCREEN']
          ENV['PDC_RESTORE_SCREEN'] = '1'
          expect(::Curses).to receive(:init_screen) do
            expect(ENV['PDC_RESTORE_SCREEN']).to eq('0')
          end
          Fatty::Curses::Context.new.send(:initialize_screen!)
          expect(ENV['PDC_RESTORE_SCREEN']).to eq('1')
        ensure
          ENV['PDC_RESTORE_SCREEN'] = original
        end

        it "does not change screen selection on ncurses" do
          stub_const('Curses::VERSION', 'ncurses 6.5')
          original = ENV['PDC_RESTORE_SCREEN']
          expect(::Curses).to receive(:init_screen) do
            expect(ENV['PDC_RESTORE_SCREEN']).to eq(original)
          end
          Fatty::Curses::Context.new.send(:initialize_screen!)
        end
      end

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
        it "rejects unsupported suspension before changing terminal modes" do
          context = Fatty::Curses::Context.new
          context.instance_variable_set(:@started, true)
          allow(Fatty::Curses::Native).to receive(:prepare_suspend!).and_raise(
            Fatty::Curses::Native::SuspensionUnavailable, 'no endwin')
          expect(::Curses).not_to receive(:def_prog_mode)
          expect(context).not_to receive(:disable_bracketed_paste!)
          expect(::Curses).not_to receive(:close_screen)
          expect { context.suspend }.to raise_error(Fatty::Curses::Native::SuspensionUnavailable)
        end

        it "saves curses program mode and returns the terminal to shell mode" do
          context = Fatty::Curses::Context.new
          context.instance_variable_set(:@started, true)

          allow(context).to receive(:disable_bracketed_paste!)
          allow(::Curses).to receive(:def_prog_mode)
          allow(::Curses).to receive(:curs_set)
          allow(Fatty::Curses::Native).to receive(:prepare_suspend!)
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
          stdscr = instance_double(::Curses::Window, touch: nil)

          allow(context).to receive(:enable_bracketed_paste!)
          allow(::Curses).to receive(:reset_prog_mode)
          allow(::Curses).to receive(:refresh)
          allow(::Curses).to receive(:stdscr).and_return(stdscr)

          context.resume

          expect(::Curses).to have_received(:reset_prog_mode).ordered
          expect(::Curses).to have_received(:refresh).ordered
          expect(stdscr).to have_received(:touch)
          expect(context).to have_received(:enable_bracketed_paste!)
        end
      end
    end
  end
end
