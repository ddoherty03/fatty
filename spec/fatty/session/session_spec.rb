# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Session do
    describe "#initialize" do
      it "sets a generated id, keymap, and counter" do
        keymap = instance_double(Fatty::KeyMap)
        session = Fatty::Session.new(keymap: keymap)

        expect(session.id).to match(/\Asession_\d+\z/)
        expect(session.keymap).to be(keymap)
        expect(session.counter).to be_a(Fatty::Counter)
      end

      it "uses an explicit id" do
        session = Fatty::Session.new(id: :mine)

        expect(session.id).to eq(:mine)
      end
    end

    describe "#init" do
      it "stores the terminal and returns no commands" do
        terminal = instance_double(Fatty::Terminal)
        session = Fatty::Session.new

        commands = session.init(terminal: terminal)

        expect(commands).to eq([])
        expect(session.terminal).to be(terminal)
      end
    end

    describe "#update" do
      it "returns nil by default" do
        session = Fatty::Session.new

        expect(session.update(Fatty::Command.session(session.id, :anything))).to be_nil
      end
    end

    describe "#view" do
      it "does nothing" do
        session = Fatty::Session.new

        expect(session.view).to be_nil
      end
    end

    describe "#close" do
      it "does nothing" do
        session = Fatty::Session.new

        expect(session.close).to be_nil
      end
    end

    describe "#persist!" do
      it "does nothing" do
        session = Fatty::Session.new

        expect(session.persist!).to be_nil
      end
    end

    describe "#tick" do
      it "returns false" do
        session = Fatty::Session.new

        expect(session.tick).to be(false)
      end
    end

    describe "#renderer" do
      it "delegates to terminal.renderer" do
        renderer = instance_double(Fatty::Renderer)
        terminal = instance_double(Fatty::Terminal, renderer: renderer)
        session = Fatty::Session.new
        session.init(terminal: terminal)

        expect(session.renderer).to be(renderer)
      end
    end

    describe "#screen" do
      it "delegates to terminal.screen" do
        screen = instance_double(Fatty::Screen)
        terminal = instance_double(Fatty::Terminal, screen: screen)
        session = Fatty::Session.new
        session.init(terminal: terminal)

        expect(session.screen).to be(screen)
      end
    end

    describe "session actions" do
      it "defines :count_digit" do
        session = Fatty::Session.new
        env = Fatty::ActionEnvironment.new(session: session, event: nil)
        result = Fatty::Actions.call(:count_digit, env, 4)
        expect(result).to be(session.counter)
        expect(session.counter.digits).to eq("4")
      end

      it "clears count digits" do
        session = Fatty::Session.new

        env = Fatty::ActionEnvironment.new(session: session, event: nil)
        Fatty::Actions.call(:count_digit, env, 4)
        Fatty::Actions.call(:count_clear, env)
        expect(session.counter.digits).to eq("")
      end

      it "handles universal argument" do
        session = Fatty::Session.new

        env = Fatty::ActionEnvironment.new(session: session, event: nil)
        Fatty::Actions.call(:universal_argument, env)
        expect(session.counter.value).to eq(4)
        Fatty::Actions.call(:universal_argument, env)
        expect(session.counter.value).to eq(16)
      end
    end
  end
end
