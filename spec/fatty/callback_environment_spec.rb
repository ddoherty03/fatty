# frozen_string_literal: true

module Fatty
  RSpec.describe CallbackEnvironment do
    let(:renderer) { instance_double(Fatty::Renderer, palette: nil) }
    let(:terminal) {
      instance_double(
        Fatty::Terminal,
        renderer: renderer,
        apply_command: nil,
      )
    }
    let(:env) { Fatty::CallbackEnvironment.new(terminal: terminal, output_id: :output) }

    describe "#append" do
      it "queues an output append command and returns nil" do
        result = env.append("hello", follow: false)

        expect(result).to be_nil
        expect(env.commands.length).to eq(1)
        expect(env.commands.first.target).to eq(:output)
        expect(env.commands.first.action).to eq(:append)
        expect(env.commands.first.payload).to eq(text: "hello", follow: false)
      end
    end

    describe "#markdown" do
      it "renders markdown and queues the rendered output" do
        allow(Fatty::Markdown)
          .to receive(:render)
                .with("**hi**", palette: nil)
                .and_return("rendered")
        allow(Fatty::Markdown)
          .to receive(:render)
                .with("**hi**", palette: nil, theme: anything, truecolor: false)
                .and_return("rendered")

        result = env.markdown("**hi**")

        expect(result).to be_nil
        expect(env.commands.first.target).to eq(:output)
        expect(env.commands.first.action).to eq(:append)
        expect(env.commands.first.payload[:text]).to eq("rendered")
      end
    end

    describe "#status" do
      it "applies a status command immediately and does not queue it" do
        result = env.status("Working", role: :good)

        expect(result).to be_nil
        expect(env.commands).to eq([])
        expect(terminal).to have_received(:apply_command) do |command|
          expect(command.target).to eq(:status)
          expect(command.action).to eq(:show)
          expect(command.payload).to eq(text: "Working", role: :good)
        end
      end
    end

    describe "#alert" do
      it "applies an alert command immediately and does not queue it" do
        result = env.alert("Careful", role: :warn)

        expect(result).to be_nil
        expect(env.commands).to eq([])
        expect(terminal).to have_received(:apply_command) do |command|
          expect(command.target).to eq(:alert)
          expect(command.action).to eq(:show)
          expect(command.payload).to eq(text: "Careful", role: :warn)
        end
      end
    end

    describe "#queue" do
      it "stores and returns the command" do
        command = Fatty::Command.session(:output, :append, text: "x")

        result = env.queue(command)

        expect(result).to be(command)
        expect(env.commands).to eq([command])
      end
    end

    describe "#check_interrupt!" do
      before do
        allow(terminal).to receive(:interrupt_pending?).and_return(false)
        allow(env).to receive(:monotonic_time).and_return(10.0)
      end

      it "polls for an interrupt" do
        expect(env.check_interrupt!).to be_nil

        expect(terminal).to have_received(:interrupt_pending?).once
      end

      it "raises Fatty::Interrupt when an interrupt is pending" do
        allow(terminal).to receive(:interrupt_pending?).and_return(true)

        expect { env.check_interrupt! }.to raise_error(Fatty::Interrupt)
      end

      it "throttles repeated polling" do
        allow(env).to receive(:monotonic_time).and_return(10.0, 10.5, 11.0)

        env.check_interrupt!
        env.check_interrupt!
        env.check_interrupt!

        expect(terminal).to have_received(:interrupt_pending?).twice
      end
    end
  end
end
