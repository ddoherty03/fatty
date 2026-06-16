# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe PromptApi do
    let(:event_source_class) do
      Class.new do
        def initialize(command)
          @command = command
        end

        def next_event
          command = @command
          @command = nil
          command
        end
      end
    end

    let(:terminal_class) do
      event_source = event_source_class

      Class.new do
        attr_reader :applied_commands, :event_source

        define_method(:initialize) do |event_command:|
          @applied_commands = []
          @event_source = event_source.new(event_command)
          @running = true
        end

        def apply_command(command)
          @applied_commands << command
          if owner_command?(command)
            @owner.update(command)
            @running = false
          else
            capture_owner(command)
            []
          end
        end

        def render_frame; end

        def running?
          @running
        end

        def tick_active_session
          false
        end

        private

        # simplecov:disable

        def capture_owner(command)
          if command.target == :terminal && command.action == :push_modal
            @owner = command.payload.fetch(:owner)
          end
        end

        def owner_command?(command)
          [
            :prompt_result,
            :prompt_cancelled,
          ].include?(command.action)
        end
      end
    end

    def terminal_entering(text)
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :prompt_result, text: text),
      )
    end

    def terminal_cancelling
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :prompt_cancelled),
      )
    end

    def env_for(terminal)
      Fatty::CallbackEnvironment.new(terminal: terminal, output_id: :output)
    end

    describe "#prompt" do
      it "pushes a prompt modal" do
        terminal = terminal_entering("hello")
        env = env_for(terminal)

        env.prompt("Name?")

        command = terminal.applied_commands.first
        expect(command.target).to eq(:terminal)
        expect(command.action).to eq(:push_modal)
        expect(command.payload.fetch(:session)).to be_a(Fatty::PromptSession)
        expect(command.payload.fetch(:owner)).to be_a(Fatty::Terminal::PopupOwner)
      end

      it "returns entered text" do
        terminal = terminal_entering("hello")
        env = env_for(terminal)

        expect(env.prompt("Name?")).to eq("hello")
      end

      it "returns quit value when cancelled" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        result = env.prompt("Name?", quit_value: :quit)

        expect(result).to eq(:quit)
      end

      it "passes initial text into the prompt session" do
        terminal = terminal_entering("hello")
        env = env_for(terminal)

        env.prompt("Name?", initial: "Dan")

        session = terminal.applied_commands.first.payload.fetch(:session)
        expect(session.field.buffer.text).to eq("Dan")
      end

      it "uses the prompt text as the default history context prompt" do
        terminal = terminal_entering("hello")
        env = env_for(terminal)

        env.prompt("Name?")

        session = terminal.applied_commands.first.payload.fetch(:session)
        expect(session.field.send(:resolve_history_ctx).fetch(:prompt)).to eq("Name?")
      end

      it "uses history_key when supplied" do
        terminal = terminal_entering("hello")
        env = env_for(terminal)

        env.prompt("Name?", history_key: :person_name)

        session = terminal.applied_commands.first.payload.fetch(:session)
        expect(session.field.send(:resolve_history_ctx).fetch(:prompt)).to eq("person_name")
      end
    end
  end
end
