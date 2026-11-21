# frozen_string_literal: true

require "spec_helper"

module Fatty
  module Curses
    RSpec.describe WindowsKeyboard do
      let(:key_scan) { instance_double(Fiddle::Function) }

      before do
        allow(Gem).to receive(:win_platform?).and_return(true)
        allow(WindowsKeyboard).to receive(:key_scan).and_return(key_scan)
      end

      it "distinguishes an ordinary backtick from an AltGr character" do
        allow(key_scan).to receive(:call).with(96).and_return(0xc0)
        allow(key_scan).to receive(:call).with(64).and_return(0x0651)
        expect(WindowsKeyboard.altgr_character?("`")).to be(false)
        expect(WindowsKeyboard.altgr_character?("@")).to be(true)
      end

      it "preserves characters requiring Shift with AltGr" do
        allow(key_scan).to receive(:call).and_return(0x0751)
        expect(WindowsKeyboard.altgr_character?("@")).to be(true)
      end

      it "preserves text when the layout cannot map the character" do
        allow(key_scan).to receive(:call).and_return(-1)
        expect(WindowsKeyboard.altgr_character?("é")).to be(true)
      end

      it "preserves text when the Windows API is unavailable" do
        allow(WindowsKeyboard).to receive(:key_scan).and_raise(Fiddle::DLError)
        expect(WindowsKeyboard.altgr_character?("@")).to be(true)
      end

      it "does not load Windows APIs on other platforms" do
        allow(Gem).to receive(:win_platform?).and_return(false)
        expect(WindowsKeyboard.altgr_character?("@")).to be(true)
        expect(WindowsKeyboard).not_to have_received(:key_scan)
      end
    end
  end
end
