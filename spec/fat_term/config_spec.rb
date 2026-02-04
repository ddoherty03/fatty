# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module FatTerm
  RSpec.describe "FatTerm::Config with real FatConfig::Reader" do
    def write_cfg(dir, name, content)
      path = File.join(dir, "fat_term", "#{name}.yml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      path
    end

    around do |ex|
      old_xdg = ENV["XDG_CONFIG_HOME"]

      Dir.mktmpdir("fat_term_config") do |tmp|
        ENV["XDG_CONFIG_HOME"] = tmp
        ex.run
      end
    ensure
      ENV["XDG_CONFIG_HOME"] = old_xdg
    end

    # ------------------------------------------------------------------
    # config.yml
    # ------------------------------------------------------------------

    describe "config.yml" do
      it "loads a valid config.yml" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
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

      it "raises when config.yml is invalid YAML" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
          "config",
          "log: [this is not valid yaml",
        )

        expect {
          Config.config
        }.to raise_error do |err|
          # Don’t lock class yet; inspect first
          expect(err.class.name).to match(/FatConfig|Parse|YAML/)
        end
      end
    end

    # ------------------------------------------------------------------
    # keydefs.yml
    # ------------------------------------------------------------------

    describe "keydefs.yml" do
      it "loads structured terminal key definitions" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
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

      it "raises when keydefs.yml is invalid YAML" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
          "keydefs",
          "terminal: [this is not valid yaml",
        )

        expect {
          Config.keydefs
        }.to raise_error do |err|
          expect(err.class.name).to match(/FatConfig|Parse|YAML/)
        end
      end
    end

    # ------------------------------------------------------------------
    # keybindings.yml
    # ------------------------------------------------------------------

    describe "keybindings.yml" do
      it "loads valid keybindings.yml" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
          "keybindings",
          <<~YAML,
            - key: left
              meta: true
              action: backward_word

            - key: right
              meta: false
              action: forward_word
          YAML
        )

        bindings = Config.keybindings
        expect(bindings).to be_a(Array)
        expect(bindings.first[:key]).to eq("left")
        expect(bindings.first[:meta]).to be true
        expect(bindings.first[:action]).to eq("backward_word")
        expect(bindings[1][:key]).to eq("right")
        expect(bindings[1][:meta]).to be false
        expect(bindings[1][:action]).to eq("forward_word")
      end

      it "returns empty Hash when keybindings.yml is missing" do
        bindings = Config.keybindings
        expect(bindings).to eq({})
      end

      it "raises when keybindings.yml is invalid YAML" do
        write_cfg(
          ENV["XDG_CONFIG_HOME"],
          "keybindings",
          "keybindings: [this is broken"
        )

        expect {
          Config.keybindings
        }.to raise_error FatConfig::ParseError
      end
    end
  end
end
