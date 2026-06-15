# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe OutputApi do
    let(:renderer) { instance_double(Fatty::Renderer, palette: :palette) }
    let(:terminal) { instance_double(Fatty::Terminal, renderer: renderer) }

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
