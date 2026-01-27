# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe Session do
    let(:terminal)  { instance_double(Terminal) }
    let(:screen)    { instance_double(Screen) }
    let(:renderer)  { instance_double(Backends::Curses::Renderer) }

    describe "#init" do
      it "returns [self, []] by default" do
        s = Session.new
        model, commands = s.init(terminal:)

        expect(model).to be(s)
        expect(commands).to eq([])
      end
    end

    describe "#update" do
      it "returns [self, []] by default" do
        s = Session.new
        model, commands = s.update(:message, terminal:)

        expect(model).to be(s)
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

      it "does nothing if it has no views" do
        s = Session.new
        expect { s.view(screen:, renderer:, terminal:) }.not_to raise_error
      end
    end

    describe "#pack" do
      it "normalizes nil to [self, []]" do
        s = Session.new
        model, commands = s.pack(nil)

        expect(model).to be(s)
        expect(commands).to eq([])
      end

      it "wraps a single command into [self, [command]]" do
        s = Session.new
        cmd = [:beep]

        model, commands = s.pack(cmd)

        expect(model).to be(s)
        expect(commands).to eq([cmd])
      end

      it "passes through an array of commands as [self, commands]" do
        s = Session.new
        cmds = [[:beep], [:open, "file.txt"]]

        model, commands = s.pack(cmds)

        expect(model).to be(s)
        expect(commands).to eq(cmds)
      end

      it "accepts a Charm tuple [self, commands]" do
        s = Session.new
        cmds = [[:beep]]

        model, commands = s.pack([s, cmds])

        expect(model).to be(s)
        expect(commands).to eq(cmds)
      end

      it "coerces tuple commands to an array (nil => [])" do
        s = Session.new
        model, commands = s.pack([s, nil])

        expect(model).to be(s)
        expect(commands).to eq([])
      end

      it "treats [:cmd] as a single command, not a commands list" do
        s = Session.new
        model, commands = s.pack([:beep])
        expect(model).to be(s)
        expect(commands).to eq([[:beep]])
      end
    end
  end
end
