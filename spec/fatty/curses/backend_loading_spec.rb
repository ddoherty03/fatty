# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'Curses backend loading' do
  it 'loads without mouse APIs or a process-wide endwin symbol' do
    script = <<~'RUBY'
      require 'curses'
      require 'fiddle/import'
      Curses.constants.grep(/BUTTON|MOUSE/).each { |name| Curses.send(:remove_const, name) }
      [:mousemask, :getmouse].each do |name|
        Curses.singleton_class.send(:undef_method, name) if Curses.respond_to?(name)
      end
      module Fiddle
        def self.dlopen(*)
          raise DLError, 'no process-wide endwin'
        end
      end
      require 'fatty'
      abort 'missing console sizing support' unless STDOUT.respond_to?(:winsize)
      abort 'loaded debugger at runtime' if defined?(DEBUGGER__)
      abort 'invented mouse support' if Curses.const_defined?(:BUTTON1_PRESSED)
      def Curses.endwin
        true
      end
      abort 'did not use Ruby binding' unless Fatty::Curses::Native.endwin == true
      def Curses.endwin
        false
      end
      begin
        Fatty::Curses::Native.endwin
        abort 'ignored suspension failure'
      rescue Fatty::Curses::Native::SuspensionUnavailable
      end
      puts 'loaded' 
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', script)
    expect(status.success?).to be(true), stderr
    expect(stdout).to include('loaded')
  end
end
