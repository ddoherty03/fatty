# frozen_string_literal: true

module Fatty
  RSpec.describe MenuApi do
    def renderer
      instance_double(Fatty::Renderer, palette: nil)
    end

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
        attr_reader :applied_commands, :returned_commands, :event_source, :renderer

        define_method(:initialize) do |event_command:, renderer:|
          @applied_commands = []
          @returned_commands = []
          @event_source = event_source.new(event_command)
          @renderer = renderer
          @running = true
        end

        def apply_command(command)
          @applied_commands << command
          result =
            if popup_owner_command?(command)
              @owner.update(command)
            else
              capture_popup_owner(command)
              []
            end
          @returned_commands.concat(result)
          @running = false if popup_owner_command?(command)
          result
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

        def capture_popup_owner(command)
          if command.target == :terminal && command.action == :push_modal
            @owner = command.payload.fetch(:owner)
          end
        end

        def popup_owner_command?(command)
          [
            :popup_result,
            :prompt_result,
            :popup_cancelled,
            :prompt_cancelled,
            :popup_changed,
          ].include?(command.action)
        end
      end
    end

    def terminal_selecting(label)
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :popup_result, item: label),
        renderer: renderer,
      )
    end

    def terminal_cancelling
      terminal_class.new(
        event_command: Fatty::Command.session(:active, :popup_cancelled),
        renderer: renderer,
      )
    end

    def env_for(terminal)
      Fatty::CallbackEnvironment.new(terminal: terminal, output_id: :output)
    end

    describe "#menu" do
      # let(:env) { env_for(terminal_selecting("One")) }
      # let(:env_cancelling) { env_for(terminal_cancelling) }
      # let(:menu) {
      #   env.menu("Choose",
      #     choices: {
      #       "One" => ->(_fatty, _label) { :one },
      #       "Two" => ->(_fatty, _label) { :two },
      #     },
      #     cancel_value: :quit
      #   )
      # }

      it "pushes a popup modal" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        env.menu("Choose",
          choices: {
            "One" => ->(_fatty, _label) { :one },
            "Two" => ->(_fatty, _label) { :two },
          }
        )

        command = terminal.applied_commands.first
        expect(command.target).to eq(:terminal)
        expect(command.action).to eq(:push_modal)
        expect(command.payload.fetch(:session)).to be_a(Fatty::PopUpSession)
        expect(command.payload.fetch(:owner)).to be_a(Fatty::Terminal::PopupOwner)
      end

      it "returns the quit value when cancelled" do
        terminal = terminal_cancelling
        env = env_for(terminal)

        result =
          env.menu("Choose", choices: {
            "One" => ->(_fatty, _label) { :one },
            "Two" => ->(_fatty, _label) { :two },
          },
          cancel_value: :quit)

        expect(result).to eq(:quit)
      end

      it "passes a callback environment to callable menu items" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)
        callback_env = nil

        env.menu(
          "Choose",
          choices:
            {
              "One" => proc do |inner_env, _label|
                callback_env = inner_env
               :done
              end,
            },
        )
        expect(callback_env).to be_a(Fatty::CallbackEnvironment)
      end

      it "queues nested callback commands onto the outer environment" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        result = env.menu(
          "Choose",
          choices: {
            "One" => proc do |inner_env|
                       inner_env.append("hello")
                       :done
                     end
          },
        )

        expect(result).to eq(:done)
        expect(env.commands.length).to eq(1)
        command = env.commands.first
        expect(command.target).to eq(:output)
        expect(command.action).to eq(:append)
        expect(command.payload).to eq(text: "hello", follow: true)
      end

      it "preserves order for multiple queued nested commands" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        env.menu(
          "Choose",
          choices: {
            "One" => proc do |inner_env|
               inner_env.append("one")
               inner_env.append("two", follow: false)
             end,
          },
        )

        expect(env.commands.map { |command| command.payload.fetch(:text) })
          .to eq(["one", "two"])
        expect(env.commands.map { |command| command.payload.fetch(:follow) })
          .to eq([true, false])
      end

      it "applies immediate nested callback commands without queueing them" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        env.menu(
          "Choose",
          choices: {
            "One" => proc do |inner_env|
               inner_env.status("working", role: :good)
               inner_env.append("hello")
             end,
          },
        )
        status_command = terminal.applied_commands.find do |command|
          command.target == :status && command.action == :show
        end
        expect(status_command.payload).to eq(text: "working", role: :good)
        expect(env.commands.length).to eq(1)
        expect(env.commands.first.payload.fetch(:text)).to eq("hello")
      end

      it "raises when a menu choice is not callable" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)
        expect {
          env.menu("Choose", choices: { "One" => :one })
        }.to raise_error(ArgumentError, 'menu choice "One" is not callable')
      end

      it "raises when choices are empty" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)

        expect { env.menu("Choose", choices: {}) }
          .to raise_error(ArgumentError, "choices must not be empty")
      end

      it "raises an error for non-Hash choices" do
        terminal = terminal_selecting("One")
        env = env_for(terminal)
        expect {
          env.menu("Choose", choices: [])
        }.to raise_error(ArgumentError, "menu choices must be a Hash of label => callable")
      end
    end
  end
end
