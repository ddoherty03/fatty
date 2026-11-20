# frozen_string_literal: true

require "open3"
require "shellwords"
require "tempfile"

module Fatty
  # Capture noninteractive shell output. On native Windows, avoid the threaded
  # pipe reader that can stall after PDCurses console input.
  module Shell
    # Demo command arguments are shell-like, but Windows backslashes are
    # path separators, not Unix escapes. External commands keep the original line.
    def self.split_arguments(line)
      line = line.gsub("\\") { "\\\\" } if Gem.win_platform?
      Shellwords.split(line)
    end

    def self.capture(line)
      return Open3.capture2e(line) unless Gem.win_platform?

      Tempfile.create("fatty-command") do |output|
        pid = Process.spawn(line, in: File::NULL, out: output, err: [:child, :out])
        _, status = Process.wait2(pid)
        output.rewind
        [output.read, status]
      end
    end
  end
end
