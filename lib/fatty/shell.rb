# frozen_string_literal: true

require "fiddle"
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
        output.binmode
        output.rewind
        [decode_windows_output(output.read).gsub("\r\n", "\n"), status]
      end
    end

    # Some external programs emit UTF-8 even when cmd.exe uses a legacy page.
    def self.decode_windows_output(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?

      text.force_encoding(windows_output_encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
    private_class_method :decode_windows_output

    def self.windows_output_encoding
      @code_page_functions ||= begin
        library = Fiddle.dlopen("kernel32.dll")
        abi = if Fiddle::Function.const_defined?(:STDCALL)
          Fiddle::Function::STDCALL
        else
          Fiddle::Function::DEFAULT
        end
        ["GetConsoleOutputCP", "GetOEMCP"].map do |name|
          Fiddle::Function.new(library[name], [], Fiddle::TYPE_INT, abi)
        end
      end
      page = @code_page_functions[0].call
      page = @code_page_functions[1].call if page.zero?
      Encoding.find(page == 65001 ? "UTF-8" : "CP#{page}")
    rescue ArgumentError, Fiddle::DLError
      Encoding::UTF_8
    end
    private_class_method :windows_output_encoding
  end
end
