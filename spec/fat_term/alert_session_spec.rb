# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe AlertSession do
    let(:terminal) { instance_double(Terminal) }
    let(:screen)   { instance_double(Screen) }
    let(:renderer) { instance_double(Backends::Curses::Renderer) }

    it "has an AlertView and renders via the default Session#view pipeline" do
      s = AlertSession.new

      expect(s.views.map(&:class)).to include(FatTerm::AlertView)

      allow(renderer).to receive(:render_alert)

      s.update([:cmd, :show, { level: :warning, message: "hi" }], terminal: terminal)
      s.view(screen: screen, renderer: renderer, terminal: terminal)

      expect(renderer).to have_received(:render_alert).with(instance_of(FatTerm::Alert))
      expect(s.current.level).to eq(:warning)
      expect(s.current.message).to eq("hi")
    end

    it "does not clear sticky alerts" do
      s = AlertSession.new

      s.update([:cmd, :show, { message: "keep", sticky: true }], terminal: terminal)
      expect(s.current).to be_sticky

      s.update([:cmd, :clear, {}], terminal: terminal)
      expect(s.current).not_to be_nil
      expect(s.current.message).to eq("keep")
    end

    it "clears non-sticky alerts" do
      s = AlertSession.new

      s.update([:cmd, :show, { message: "bye" }], terminal: terminal)
      expect(s.current).not_to be_nil
      expect(s.current).not_to be_sticky

      s.update([:cmd, :clear, {}], terminal: terminal)
      expect(s.current).to be_nil
    end
  end
end
