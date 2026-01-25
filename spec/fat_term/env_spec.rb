# frozen_string_literal: true

module FatTerm
  RSpec.describe Env do
    around do |ex|
      old = ENV.to_hash
      begin
        ex.run
      ensure
        ENV.replace(old)
      end
    end

    def clear_terminal_env
      %w[
    TMUX STY KONSOLE_VERSION KITTY_WINDOW_ID ALACRITTY_LOG TERMINATOR_UUID
    TERM_PROGRAM TERM
      ].each { |k| ENV.delete(k) }
    end

    describe ".os" do
      it "detects linux" do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        expect(Env.os).to eq(:linux)
      end

      it "detects darwin" do
        stub_const("RUBY_PLATFORM", "arm64-darwin23")
        expect(Env.os).to eq(:darwin)
      end

      it "detects bsd" do
        stub_const("RUBY_PLATFORM", "x86_64-freebsd13")
        expect(Env.os).to eq(:bsd)
      end

      it "detects windows" do
        stub_const("RUBY_PLATFORM", "x64-mingw-ucrt")
        expect(Env.os).to eq(:windows)
      end

      it "falls back to unknown" do
        stub_const("RUBY_PLATFORM", "weird-platform")
        expect(Env.os).to eq(:unknown)
      end
    end

    describe ".arch" do
      it "detects x86_64" do
        stub_const("RUBY_PLATFORM", "x86_64-linux")
        expect(Env.arch).to eq(:x86_64)
      end

      it "detects arm64/aarch64" do
        stub_const("RUBY_PLATFORM", "aarch64-linux")
        expect(Env.arch).to eq(:arm64)

        stub_const("RUBY_PLATFORM", "arm64-darwin23")
        expect(Env.arch).to eq(:arm64)
      end

      it "falls back to unknown" do
        stub_const("RUBY_PLATFORM", "mipsel-linux")
        expect(Env.arch).to eq(:unknown)
      end
    end

    describe ".detect_terminal_program" do
      it "prefers tmux when TMUX is present" do
        ENV["TMUX"] = "1"
        ENV["KONSOLE_VERSION"] = "999"
        ENV["TERM_PROGRAM"] = "WezTerm"
        expect(Env.detect_terminal_program).to eq("tmux")
      end

      it "prefers screen when STY is present (and no TMUX)" do
        ENV.delete("TMUX")
        ENV["STY"] = "screen"
        ENV["KONSOLE_VERSION"] = "999"
        expect(Env.detect_terminal_program).to eq("screen")
      end

      it "detects konsole via KONSOLE_VERSION" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV["KONSOLE_VERSION"] = "1"
        expect(Env.detect_terminal_program).to eq("konsole")
      end

      it "detects kitty via KITTY_WINDOW_ID" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV["KITTY_WINDOW_ID"] = "abc"
        expect(Env.detect_terminal_program).to eq("kitty")
      end

      it "detects wezterm via TERM_PROGRAM=wezterm (case-insensitive)" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV["TERM_PROGRAM"] = "WezTerm"
        expect(Env.detect_terminal_program).to eq("wezterm")
      end

      it "detects iTerm via TERM_PROGRAM=iTerm.app" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV["TERM_PROGRAM"] = "iTerm.app"
        expect(Env.detect_terminal_program).to eq("iterm")
      end

      it "detects ghostty via TERM_PROGRAM=ghostty" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV["TERM_PROGRAM"] = "ghostty"
        expect(Env.detect_terminal_program).to eq("ghostty")
      end

      it "detects alacritty via ALACRITTY_LOG" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV.delete("TERM_PROGRAM")
        ENV["ALACRITTY_LOG"] = "1"
        expect(Env.detect_terminal_program).to eq("alacritty")
      end

      it "detects terminator via TERMINATOR_UUID" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV.delete("TERM_PROGRAM")
        ENV["TERMINATOR_UUID"] = "1"
        expect(Env.detect_terminal_program).to eq("terminator")
      end

      it "falls back to TERM_PROGRAM downcased when present" do
        ENV.delete("TMUX")
        ENV.delete("STY")
        ENV.delete("KONSOLE_VERSION")
        ENV.delete("KITTY_WINDOW_ID")
        ENV.delete("ALACRITTY_LOG")
        ENV.delete("TERMINATOR_UUID")
        ENV["TERM_PROGRAM"] = "CoolTerm"
        expect(Env.detect_terminal_program).to eq("coolterm")
      end

      it "falls back to TERM downcased when TERM_PROGRAM is absent" do
        clear_terminal_env
        ENV.delete("TERM_PROGRAM")
        ENV["TERM"] = "XTERM-256COLOR"
        expect(Env.detect_terminal_program).to eq("xterm-256color")
      end

      it "returns 'unknown' when no relevant env vars are present" do
        clear_terminal_env
        ENV.delete("TERM_PROGRAM")
        ENV.delete("TERM")
        expect(Env.detect_terminal_program).to eq("unknown")
      end
    end

    describe "session predicates" do
      it ".tmux? is true when TMUX is set" do
        ENV["TMUX"] = "1"
        expect(Env.tmux?).to be(true)
        ENV.delete("TMUX")
        expect(Env.tmux?).to be(false)
      end

      it ".screen? is true when STY is set" do
        ENV["STY"] = "screen"
        expect(Env.screen?).to be(true)
        ENV.delete("STY")
        expect(Env.screen?).to be(false)
      end

      it ".ssh? is true when SSH_TTY or SSH_CONNECTION is set" do
        ENV["SSH_TTY"] = "/dev/pts/1"
        expect(Env.ssh?).to be(true)

        ENV.delete("SSH_TTY")
        ENV["SSH_CONNECTION"] = "a b c d"
        expect(Env.ssh?).to be(true)

        ENV.delete("SSH_CONNECTION")
        expect(Env.ssh?).to be(false)
      end
    end

    describe ".curses_info" do
      it "returns {} when Curses is not defined" do
        hide_const("Curses") if defined?(Curses)
        expect(Env.curses_info).to eq({})
      end

      it "returns key_min/key_max when Curses is defined" do
        stub_const("Curses", Module.new)
        Curses.const_set(:KEY_MIN, 1)
        Curses.const_set(:KEY_MAX, 999)

        expect(Env.curses_info).to eq({ key_min: 1, key_max: 999 })
      end

      it "returns {} if Curses access raises" do
        stub_const("Curses", Module.new)
        # Simulate a weird curses implementation raising on constant access
        def Curses.const_missing(_name)
          raise "boom"
        end

        expect(Env.curses_info).to eq({})
      end
    end
  end
end
