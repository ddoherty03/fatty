# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe Session do
    let(:terminal)  { instance_double(Terminal) }
    let(:screen)    { instance_double(Screen) }
    let(:renderer)  { instance_double(Curses::Renderer) }

    describe "#init" do
      it "returns [self, []] by default" do
        s = Session.new
        commands = s.init(terminal:)

        expect(commands).to eq([])
      end
    end

    describe "#update" do
      it "returns [] by default" do
        s = Session.new
        commands = s.update(:message, terminal:)

        expect(commands).to eq([])
      end

      it "dispatches key messages and returns [] by default" do
        s = Session.new
        commands = s.update([:key, :doit], terminal:)

        expect(commands).to eq([])
      end

      it "dispatches cmd messages and returns [] by default" do
        s = Session.new
        commands = s.update([:cmd, :doit], terminal:)

        expect(commands).to eq([])
      end
    end

    describe "#view" do
      it "renders its views in ascending z order" do
        v1 = instance_double(View, z: 10)
        v2 = instance_double(View, z: 0)
        v3 = instance_double(View, z: 5)

        s = Session.new(views: [v1, v2, v3])

        allow(v1).to receive(:render)
        allow(v2).to receive(:render)
        allow(v3).to receive(:render)

        s.view(screen:, renderer:, terminal:)

        expect(v2).to have_received(:render).ordered
        expect(v3).to have_received(:render).ordered
        expect(v1).to have_received(:render).ordered
      end

      describe "#add_view" do
        it "renders its views in ascending z order" do
          v1 = instance_double(View, z: 10)
          v2 = instance_double(View, z: 0)

          s = Session.new(views: [v1, v2])
          v3 = instance_double(View, z: 5)
          s.add_view(v3)

          allow(v1).to receive(:render)
          allow(v2).to receive(:render)
          allow(v3).to receive(:render)

          s.view(screen:, renderer:, terminal:)

          expect(v2).to have_received(:render).ordered
          expect(v3).to have_received(:render).ordered
          expect(v1).to have_received(:render).ordered
        end
      end

      it "does nothing if it has no views" do
        s = Session.new
        expect { s.view(screen:, renderer:, terminal:) }.not_to raise_error
      end
    end
  end
end
