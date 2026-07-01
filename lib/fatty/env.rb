# frozen_string_literal: true

module Fatty
  module Env
    extend self

    def detect
      {
        arch: arch,
        os: os,
        ruby_platform: RUBY_PLATFORM,
        screen: screen?,
        ssh: ssh?,
        term: ENV["TERM"],
        terminal: detect_terminal_program,
        terminal_version: ENV["KONSOLE_VERSION"] || ENV["TERM_PROGRAM_VERSION"],
        tmux: tmux?,
        truecolor_detected: truecolor_detected?,
        curses: {},
      }
    end

    private

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

    def self.truecolor_detected?
      colorterm = ENV["COLORTERM"].to_s
      term = ENV["TERM"].to_s
      term_program = ENV["TERM_PROGRAM"].to_s

      colorterm.match?(/truecolor|24bit/i) ||
      term.match?(/truecolor|24bit|direct/i) ||
      term.match?(/kitty|wezterm|alacritty|ghostty|foot/i) ||
        term_program.match?(/kitty|wezterm|alacritty|ghostty|iTerm/i)
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
  end
end
