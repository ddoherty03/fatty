# frozen_string_literal: true

require "fiddle"

module Fatty
  module Ansi
    # PDCurses changes output modes while drawing. Enable VT for each Ruby
    # ANSI write, preserving the console mode owned by the curses backend.
    module WindowsConsole
      def self.with_ansi(io)
        return yield unless Gem.win_platform? && io.respond_to?(:tty?) && io.tty?

        api = functions
        handle = api[:handle].call(-11)
        buffer = [0].pack("L")
        return yield if api[:get].call(handle, buffer).zero?

        mode = buffer.unpack1("L")
        changed = api[:set].call(handle, mode | 0x0005) != 0
        begin
          yield
        ensure
          api[:set].call(handle, mode) if changed
        end
      end

      # External programs need ordinary processed output, wrapping and ANSI.
      # PDCurses can leave these disabled even after endwin. Configure both
      # streams for the whole child command, then restore before curses resumes.
      def self.with_shell_output
        return yield unless Gem.win_platform?

        api = functions
        saved = []
        buffer = [0].pack("L")
        begin
          [-11, -12].each do |stream|
            handle = api[:handle].call(stream)
            next if saved.any? { |entry| entry.first == handle }

            next if api[:get].call(handle, buffer).zero?

            mode = buffer.unpack1("L")
            shell_mode = (mode | 0x0007) & ~0x0008
            saved << [handle, mode] if api[:set].call(handle, shell_mode).nonzero?
          end
          yield
        ensure
          saved.reverse_each { |handle, mode| api[:set].call(handle, mode) }
        end
      end

      def self.functions
        @functions ||= begin
          library = Fiddle.dlopen("kernel32.dll")
          {
            handle: Fiddle::Function.new(library["GetStdHandle"], [Fiddle::TYPE_LONG], Fiddle::TYPE_VOIDP),
            get: Fiddle::Function.new(library["GetConsoleMode"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT),
            set: Fiddle::Function.new(library["SetConsoleMode"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG], Fiddle::TYPE_INT),
          }
        end
      end
      private_class_method :functions
    end
  end
end
