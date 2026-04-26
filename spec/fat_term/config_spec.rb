# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"

module Fatty
  RSpec.describe "Fatty::Config with real FatConfig::Reader" do
    def write_cfg(dir, name, content)
      path = File.join(dir, "#{name}.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      path
    end

    around do |ex|
      old_xdg = ENV["XDG_CONFIG_HOME"]
      Config.progname = progname
      Config.dir = nil
      Dir.mktmpdir("fat_term_config") do |tmp|
        ENV["XDG_CONFIG_HOME"] = tmp
        ex.run
      end
    ensure
      Config.dir = nil
      ENV["XDG_CONFIG_HOME"] = old_xdg
    end

    let(:progname) { 'spec_app' }

    describe 'path names' do
      it "returns default names of the user paths before they exist" do
        path = Config.user_config_path
        expect(path).to match(/~\/\.config\/.*config.yml/)
        path = Config.user_keydefs_path
        expect(path).to match(/keydefs.yml/)
        path = Config.user_keybindings_path
        expect(path).to match(/keybindings.yml/)
      end

      it "returns the actual name of the user path after its exists" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "config",
          <<~YAML,
            log:
              level: debug
              tags: [all]
          YAML
        )
        path = Config.user_config_path
        expect(path).to match(/tmp.*config.yml/)
      end

      it "returns file from an explicitly set user directory after its exists" do
        dir = File.join(__dir__, "../tmp/special_config_dir")
        write_cfg(
          dir,
          "config",
          <<~YAML,
            log:
              level: debug
              tags: [all]
          YAML
        )
        Config.dir = dir
        path = Config.user_config_path
        expect(path).to match(/special_config_dir.*config.yml/)
      end
    end

    describe "config.yml" do
      it "loads a valid config.yml" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "config",
          <<~YAML,
            log:
              level: debug
              tags: [all]
          YAML
        )
        cfg = Config.config
        expect(cfg).to be_a(Hash)
        expect(cfg.dig(:log, :level) || cfg.dig("log", "level")).to eq("debug").or eq(:debug)
      end

      it "returns something sensible when config.yml is missing" do
        cfg = Config.config
        expect(cfg).to be_a(Hash)
      end

      it "raises FatConfig::ParseError for invalid config.yml, warns and exits" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "config",
          "log--- : [broken",
        )
        expect { Config.config }.to raise_error(/YAML parse error/i)
      end
    end

    describe "keydefs.yml" do
      it "loads structured terminal key definitions" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "keydefs",
          <<~YAML,
            terminal:
              konsole:
                map:
                  556:
                    key: left
              kitty:
                map:
                  577:
                    key: right
              tmux:
                map:
                  555:
                    key: left
                    meta: true
                  570:
                    key: right
                    meta: true
                  557:
                    key: left
                    ctrl: true
                  572:
                    key: right
                    ctrl: true
          YAML
        )

        defs = Config.keydefs
        expect(defs).to be_a(Hash)

        terminal = defs[:terminal] || defs["terminal"]
        expect(terminal).to be_a(Hash)

        tmux = terminal[:tmux] || terminal["tmux"]
        expect(tmux).to be_a(Hash)

        map = tmux[:map] || tmux["map"]
        expect(map).to be_a(Hash)

        entry = map[555] || map["555"]
        expect(entry).to be_a(Hash)

        key = entry[:key] || entry["key"]
        expect(key).to eq("left")

        meta = entry[:meta] || entry["meta"]
        expect(meta).to be(true)
      end

      it "returns nil or empty when keydefs.yml is missing" do
        defs = Config.keydefs
        expect(defs).to eq({})
      end

      it "raises FatConfig::ParseError for invalid keydefs.yml" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "keydefs",
          "log: [broken",
        )
        expect { Config.keydefs }.to raise_error(/YAML parse error/i)
      end
    end

    describe "keybindings.yml" do
      it "loads valid keybindings.yml" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "keybindings",
          <<~YAML,
            - key: left
              meta: true
              action: move_word_left

            - key: right
              meta: false
              action: move_word_right
          YAML
        )

        bindings = Config.keybindings
        expect(bindings).to be_a(Array)
        expect(bindings.first[:key]).to eq("left")
        expect(bindings.first[:meta]).to be true
        expect(bindings.first[:action]).to eq("move_word_left")
        expect(bindings[1][:key]).to eq("right")
        expect(bindings[1][:meta]).to be false
        expect(bindings[1][:action]).to eq("move_word_right")
      end

      it "returns empty Hash when keybindings.yml is missing" do
        bindings = Config.keybindings
        expect(bindings).to eq([])
      end

      it "re-raises FatConfig::ParseError for invalid keybindings.yml (after verbose retry)" do
        write_cfg(
          File.join(ENV["XDG_CONFIG_HOME"], progname),
          "keybindings",
          "log: [broken",
        )
        expect { Config.keybindings }.to raise_error(/YAML parse error/i)
      end
    end
  end
end
