# frozen_string_literal: true

module Fatty
  module Env
    module_function

    def detect
      {
        os: os,
        arch: arch,
        ruby_platform: RUBY_PLATFORM,
        term: ENV["TERM"],
        terminal: detect_terminal_program,
        terminal_version: ENV["KONSOLE_VERSION"] || ENV["TERM_PROGRAM_VERSION"],
        tmux: tmux?,
        screen: screen?,
        ssh: ssh?,
        curses: curses_info,
      }
    end

    # -----------------------
    # OS / platform
    # -----------------------

    def os
      case RUBY_PLATFORM
      when /linux/  then :linux
      when /darwin/ then :darwin
      when /bsd/    then :bsd
      when /mswin|mingw|cygwin/ then :windows
      else :unknown
      end
    end

    def arch
      case RUBY_PLATFORM
      when /x86_64/ then :x86_64
      when /arm64|aarch64/ then :arm64
      else :unknown
      end
    end

    # -----------------------
    # Terminal identity
    # -----------------------

    def term_program
      ENV["TERM_PROGRAM"]&.downcase ||
        ENV["COLORTERM"]&.downcase
    end

    def detect_terminal_program
      return "tmux"     if ENV.key?("TMUX")
      return "screen"   if ENV.key?("STY")
      return "konsole"  if ENV.key?("KONSOLE_VERSION")
      return "kitty"    if ENV.key?("KITTY_WINDOW_ID")
      return "wezterm"  if ENV["TERM_PROGRAM"]&.downcase == "wezterm"
      return "iterm"    if ENV["TERM_PROGRAM"] == "iTerm.app"
      return "ghostty"  if ENV["TERM_PROGRAM"]&.downcase == "ghostty"
      return "alacritty" if ENV.key?("ALACRITTY_LOG")
      return "terminator" if ENV.key?("TERMINATOR_UUID")

      if ENV.key?("TERM_PROGRAM")
        ENV["TERM_PROGRAM"]&.downcase
      elsif ENV.key?("TERM")
        ENV["TERM"]&.downcase
      else
        'unknown'
      end
    end

    def tmux?
      ENV.key?("TMUX")
    end

    def screen?
      ENV.key?("STY")
    end

    def ssh?
      ENV.key?("SSH_TTY") || ENV.key?("SSH_CONNECTION")
    end

    # -----------------------
    # ncurses capabilities
    # -----------------------

    def curses_info
      return {} unless defined?(::Curses)

      {
        key_min: ::Curses::KEY_MIN,
        key_max: ::Curses::KEY_MAX,
      }
    rescue StandardError
      {}
    end
  end
end
