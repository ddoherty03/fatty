# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe ChooseApi do
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
            :popup_result,
            :popup_cancelled,
          ].include?(command.action)
        end
      end
    end

    def terminal_selecting(label)
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :popup_result, item: label),
      )
    end

    def terminal_cancelling
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :popup_cancelled),
      )
    end

    def env_for(terminal)
      Fatty::CallbackEnvironment.new(terminal: terminal, output_id: :output)
    end

    describe "#choose" do
      it "pushes a popup modal" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        env.choose("Pick", choices: [["One", :one]])

        command = terminal.applied_commands.first
        expect(command.target).to eq(:terminal)
        expect(command.action).to eq(:push_modal)
        expect(command.payload.fetch(:session)).to be_a(Fatty::PopUpSession)
        expect(command.payload.fetch(:owner)).to be_a(Fatty::Terminal::PopupOwner)
      end

      it "returns the selected value" do
        terminal = terminal_selecting("Two")
        env = env_for(terminal)

        result = env.choose(
          "Pick",
          choices: [["One", :one], ["Two", :two]],
        )

        expect(result).to eq(:two)
      end

      it "returns quit value when cancelled" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        result = env.choose(
          "Pick",
          choices: [["One", :one]],
          quit_value: :quit,
        )

        expect(result).to eq(:quit)
      end

      it "raises when choices are empty" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        expect { env.choose("Pick", choices: []) }
          .to raise_error(ArgumentError, "choices must not be empty")
      end
    end

    describe "#confirm" do
      it "returns true for Yes" do
        terminal = terminal_selecting("Yes")
        env = env_for(terminal)

        expect(env.confirm("Continue?")).to be(true)
      end

      it "returns false for No" do
        terminal = terminal_selecting("No")
        env = env_for(terminal)

        expect(env.confirm("Continue?")).to be(false)
      end

      it "returns false when cancelled" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        expect(env.confirm("Continue?")).to be(false)
      end
    end

    describe "#choose_multi" do
      it "returns selected labels mapped to values" do
        terminal = terminal_class.new(
          event_command: Fatty::Command.session(
            :active,
            :popup_result,
            items: { "One" => true, "Two" => true },
          ),
        )
        env = env_for(terminal)

        result = env.choose_multi(
          "Pick",
          choices: [["One", :one], ["Two", :two]],
        )

        expect(result).to eq("One" => :one, "Two" => :two)
      end

      it "returns quit value when cancelled" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        result = env.choose_multi(
          "Pick",
          choices: [["One", :one]],
          quit_value: :quit,
        )

        expect(result).to eq(:quit)
      end

      it "raises when choices are empty" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        expect { env.choose_multi("Pick", choices: []) }
          .to raise_error(ArgumentError, "choices must not be empty")
      end
    end
  end
end
