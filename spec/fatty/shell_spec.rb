# frozen_string_literal: true
require "spec_helper"
require "rbconfig"
require "shellwords"

RSpec.describe Fatty::Shell do
  it "preserves Windows paths in demo arguments, including quoted trailing separators" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    expect(Fatty::Shell.split_arguments('cd "C:\Program Files\Demo\"'))
      .to eq(["cd", 'C:\Program Files\Demo\\'])
    expect(Fatty::Shell.split_arguments('dir C:\Users\ded'))
      .to eq(["dir", 'C:\Users\ded'])
  end

  it "captures both streams and preserves failure status on the Windows path" do
    allow(Gem).to receive(:win_platform?).and_return(true)
    command = [RbConfig.ruby, "-e", 'STDOUT.write("out"); STDERR.write("err"); exit 7'].shelljoin
    output, status = Fatty::Shell.capture(command)
    expect(output).to include("out", "err")
    expect(status.exitstatus).to eq(7)
  end

  it "retains Open3 on Unix" do
    allow(Gem).to receive(:win_platform?).and_return(false)
    expect(Open3).to receive(:capture2e).with("echo hello").and_return(["hello", :status])
    expect(Fatty::Shell.capture("echo hello")).to eq(["hello", :status])
  end
end
