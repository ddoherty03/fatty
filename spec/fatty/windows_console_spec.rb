# frozen_string_literal: true
require "spec_helper"

RSpec.describe Fatty::Ansi::WindowsConsole do
  it "enables VT around writes and restores PDCurses mode even on failure" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    io = double(tty?: true)
    handle = double(call: 123)
    get = double
    set = double
    allow(get).to receive(:call) { |_, buffer| buffer.replace([16].pack("L")); 1 }
    expect(set).to receive(:call).with(123, 21).ordered.and_return(1)
    expect(set).to receive(:call).with(123, 16).ordered.and_return(1)
    allow(Fatty::Ansi::WindowsConsole).to receive(:functions).and_return(handle: handle, get: get, set: set)
    expect { Fatty::Ansi::WindowsConsole.with_ansi(io) { raise "write failed" } }.to raise_error("write failed")
  end

  it "does not use console APIs for redirected output" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    expect(Fatty::Ansi::WindowsConsole).not_to receive(:functions)
    expect(Fatty::Ansi::WindowsConsole.with_ansi(double(tty?: false)) { :written }).to eq(:written)
  end
end
