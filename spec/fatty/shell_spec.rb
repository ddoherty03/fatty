# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "tmpdir"

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
    Dir.mktmpdir("fatty_shell") do |dir|
      script = File.join(dir, "capture output.rb")
      File.write(script, 'STDOUT.write("out"); STDERR.write("err"); exit 7')
      # Double-quoted paths work with both cmd.exe and POSIX shells.
      command = %("#{RbConfig.ruby}" "#{script}")
      output, status = Fatty::Shell.capture(command)
      expect(output).to include("out", "err")
      expect(status.exitstatus).to eq(7)
    end
  end

  it "retains Open3 on Unix" do
    allow(Gem).to receive(:win_platform?).and_return(false)
    expect(Open3).to receive(:capture2e).with("echo hello").and_return(["hello", :status])
    expect(Fatty::Shell.capture("echo hello")).to eq(["hello", :status])
  end
end
