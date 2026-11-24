# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Ansi::WindowsConsole do
  it "enables VT around writes and restores PDCurses mode even on failure" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    io = double(tty?: true)
    handle = double(call: 123)
    get = double
    set = double
    allow(get).to receive(:call) { |_, buffer|
      buffer.replace([16].pack("L"))
      1
    }
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

RSpec.describe Fatty::Ansi::WindowsConsole, ".with_shell_output" do
  it "enables ANSI, line processing and wrapping on both streams and restores modes on error" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    handle = double
    allow(handle).to receive(:call).with(-11).and_return(101)
    allow(handle).to receive(:call).with(-12).and_return(102)
    get = double
    allow(get).to receive(:call) { |_, buffer| buffer.replace([8].pack("L")); 1 }
    set = double
    expect(set).to receive(:call).with(101, 7).ordered.and_return(1)
    expect(set).to receive(:call).with(102, 7).ordered.and_return(1)
    expect(set).to receive(:call).with(102, 8).ordered.and_return(1)
    expect(set).to receive(:call).with(101, 8).ordered.and_return(1)
    allow(Fatty::Ansi::WindowsConsole).to receive(:functions).and_return(handle: handle, get: get, set: set)
    expect { Fatty::Ansi::WindowsConsole.with_shell_output { raise "child failed" } }.to raise_error("child failed")
  end

  it "leaves redirected streams alone" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    get = double(call: 0)
    set = double
    expect(set).not_to receive(:call)
    allow(Fatty::Ansi::WindowsConsole).to receive(:functions).and_return(handle: double(call: 123), get: get, set: set)
    expect(Fatty::Ansi::WindowsConsole.with_shell_output { :done }).to eq(:done)
  end

  it "does not call Windows APIs on Unix" do
    allow(Gem).to receive(:win_platform?).and_return(false)
    expect(Fatty::Ansi::WindowsConsole).not_to receive(:functions)
    expect(Fatty::Ansi::WindowsConsole.with_shell_output { :done }).to eq(:done)
  end
end
