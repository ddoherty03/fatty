# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe OutputApi do
    let(:renderer) { instance_double(Fatty::Renderer, palette: :palette) }
    let(:terminal) do
      term = instance_double(Fatty::Terminal, renderer: renderer)
      allow(term).to receive(:apply_command)
      term
    end

    let(:env) do
      Fatty::CallbackEnvironment.new(
        terminal: terminal,
        output_id: :output,
      )
    end

    describe "#append" do
      it "queues an output append command and returns nil" do
        result = env.append("hello")

        expect(result).to be_nil
        expect(env.commands.length).to eq(1)
        expect(env.commands.first.target).to eq(:output)
        expect(env.commands.first.action).to eq(:append)
        expect(env.commands.first.payload).to eq(text: "hello", follow: true)
      end

      it "honors follow" do
        env.append("hello", follow: false)

        expect(env.commands.first.payload).to eq(text: "hello", follow: false)
      end

      it "converts text to string" do
        env.append(:hello)

        expect(env.commands.first.payload.fetch(:text)).to eq("hello")
      end
    end

    describe "#append_now" do
      it "applies an output append command and returns nil" do
        result = env.append_now("hello")

        expect(result).to be_nil
        expect(terminal)
          .to have_received(:apply_command)
                .with(have_attributes(
                        target: :output,
                        action: :append,
                        payload: { text: "hello", follow: true },
                      ))
        expect(env.commands).to be_empty
      end

      it "honors follow" do
        env.append_now("hello", follow: false)
        expect(terminal)
          .to have_received(:apply_command)
                .with(have_attributes(
                        action: :append,
                        payload: { text: "hello", follow: false },
                      ))
      end

      it "honors mode" do
        env.append_now("hello", mode: :scrolling)
        expect(terminal)
          .to have_received(:apply_command)
                .with(have_attributes(
                        action: :append,
                        payload: { text: "hello", follow: true, mode: :scrolling },
                      ))
      end

      it "converts text to string" do
        env.append_now(:hello)
        expect(terminal)
          .to have_received(:apply_command)
                .with(have_attributes(
                        action: :append,
                        payload: { text: "hello", follow: true },
                      ))
      end
    end

    describe "#markdown" do
      it "renders markdown, queues the rendered output, and returns nil" do
        allow(Fatty::Markdown)
          .to receive(:render)
          .with("**hello**", palette: :palette)
          .and_return("rendered")

        result = env.markdown("**hello**")

        expect(result).to be_nil
        expect(env.commands.length).to eq(1)
        expect(env.commands.first.target).to eq(:output)
        expect(env.commands.first.action).to eq(:append)
        expect(env.commands.first.payload).to eq(text: "rendered", follow: true)
      end
    end

    it "preserves queue order" do
      env.append("one")
      env.append("two", follow: false)

      expect(env.commands.map { |command| command.payload.fetch(:text) })
        .to eq(["one", "two"])
      expect(env.commands.map { |command| command.payload.fetch(:follow) })
        .to eq([true, false])
    end
  end
end
