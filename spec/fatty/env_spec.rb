# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Env do
    around do |example|
      old_env = ENV.to_h
      example.run
    ensure
      ENV.replace(old_env)
    end

    def clear_terminal_env!
      %w[
        TERM
        TERM_PROGRAM
        TERM_PROGRAM_VERSION
        COLORTERM
        TMUX
        STY
        KONSOLE_VERSION
        KITTY_WINDOW_ID
        ALACRITTY_LOG
        TERMINATOR_UUID
        GNOME_TERMINAL_SCREEN
        GNOME_TERMINAL_SERVICE
        VTE_VERSION
        SSH_TTY
        SSH_CONNECTION
      ].each { |key| ENV.delete(key) }
    end

    before do
      clear_terminal_env!
    end

    describe ".detect" do
      it "includes platform information" do
        info = Env.detect

        expect(info.keys).to include(
          :os,
          :arch,
          :ruby_platform,
          :term,
          :terminal,
          :terminal_version,
          :tmux,
          :screen,
          :ssh,
          :curses,
        )
        expect(info.fetch(:ruby_platform)).to eq(RUBY_PLATFORM)
      end

      it "detects tmux terminal and session state" do
        ENV["TMUX"] = "/tmp/tmux"

        info = Env.detect

        expect(info.fetch(:terminal)).to eq("tmux")
        expect(info.fetch(:tmux)).to be(true)
      end

      it "detects screen terminal and session state" do
        ENV["STY"] = "123.screen"

        info = Env.detect

        expect(info.fetch(:terminal)).to eq("screen")
        expect(info.fetch(:screen)).to be(true)
      end

      it "detects ssh session state" do
        ENV["SSH_TTY"] = "/dev/pts/1"

        expect(Env.detect.fetch(:ssh)).to be(true)
      end

      it "detects konsole and terminal version" do
        ENV["KONSOLE_VERSION"] = "240800"

        info = Env.detect

        expect(info.fetch(:terminal)).to eq("konsole")
        expect(info.fetch(:terminal_version)).to eq("240800")
      end

      it "detects kitty" do
        ENV["KITTY_WINDOW_ID"] = "1"

        expect(Env.detect.fetch(:terminal)).to eq("kitty")
      end

      it "detects wezterm case-insensitively" do
        ENV["TERM_PROGRAM"] = "WezTerm"

        expect(Env.detect.fetch(:terminal)).to eq("wezterm")
      end

      it "detects iterm" do
        ENV["TERM_PROGRAM"] = "iTerm.app"

        expect(Env.detect.fetch(:terminal)).to eq("iterm")
      end

      it "detects ghostty" do
        ENV["TERM_PROGRAM"] = "ghostty"

        expect(Env.detect.fetch(:terminal)).to eq("ghostty")
      end

      it "detects alacritty" do
        ENV["ALACRITTY_LOG"] = "/tmp/alacritty.log"

        expect(Env.detect.fetch(:terminal)).to eq("alacritty")
      end

      it "detects terminator" do
        ENV["TERMINATOR_UUID"] = "abc"

        expect(Env.detect.fetch(:terminal)).to eq("terminator")
      end

      it "detects gnome-terminal by screen environment" do
        ENV["TERM"] = "xterm-256color"
        ENV["GNOME_TERMINAL_SCREEN"] = "/org/gnome/Terminal/screen/abc"

        expect(Env.detect.fetch(:terminal)).to eq("gnome-terminal")
      end

      it "detects gnome-terminal by service environment" do
        ENV["TERM"] = "xterm-256color"
        ENV["GNOME_TERMINAL_SERVICE"] = ":1.123"

        expect(Env.detect.fetch(:terminal)).to eq("gnome-terminal")
      end

      it "detects generic vte when only VTE_VERSION is available" do
        ENV["TERM"] = "xterm-256color"
        ENV["VTE_VERSION"] = "7600"

        expect(Env.detect.fetch(:terminal)).to eq("vte")
      end

      it "prefers gnome-terminal over generic vte" do
        ENV["TERM"] = "xterm-256color"
        ENV["VTE_VERSION"] = "7600"
        ENV["GNOME_TERMINAL_SCREEN"] = "/org/gnome/Terminal/screen/abc"

        expect(Env.detect.fetch(:terminal)).to eq("gnome-terminal")
      end

      it "falls back to TERM_PROGRAM downcased" do
        ENV["TERM_PROGRAM"] = "CoolTerm"

        expect(Env.detect.fetch(:terminal)).to eq("coolterm")
      end

      it "falls back to TERM downcased" do
        ENV["TERM"] = "xterm-256color"

        expect(Env.detect.fetch(:terminal)).to eq("xterm-256color")
      end

      it "returns unknown terminal when no terminal indicators are present" do
        expect(Env.detect.fetch(:terminal)).to eq("unknown")
      end

      it "includes curses info as a hash" do
        expect(Env.detect.fetch(:curses)).to be_a(Hash)
      end
    end
  end
end
