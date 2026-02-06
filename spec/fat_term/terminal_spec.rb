# frozen_string_literal: true

require "tmpdir"
require "fileutils"

require "spec_helper"

module FatTerm
  RSpec.describe Terminal do
    def write_xdg_config(xdg_home, app:, name:, content:)
      dir = File.join(xdg_home, app)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{name}.yml"), content)
    end

    describe "#preflight!" do
      around do |ex|
        Dir.mktmpdir("fat_term_spec_xdg") do |tmp|
          old = ENV["XDG_CONFIG_HOME"]
          ENV["XDG_CONFIG_HOME"] = tmp
          ex.run
          ENV["XDG_CONFIG_HOME"] = old
        end
      end

      it "prints a configuration error and exits(1) on parse error" do
        xdg = ENV.fetch("XDG_CONFIG_HOME")

        # Broken YAML on purpose.
        write_xdg_config(
          xdg,
          app: "fat_term",
          name: "config",
          content: "log: [broken"
        )

        t = Terminal.new

        expect {
          expect { t.send(:preflight!) }.to raise_error(SystemExit) { |e|
            expect(e.status).to eq(1)
          }
        }.to output(/YAML parse error/).to_stderr
      end

      it "includes file/line information in the error message when available" do
        xdg = ENV.fetch("XDG_CONFIG_HOME")

        write_xdg_config(
          xdg,
          app: "fat_term",
          name: "config",
          content: "log: [broken",
        )

        t = Terminal.new

        expect {
          expect { t.send(:preflight!) }.to raise_error(SystemExit)
        }.to output(/at line \d+, column \d+/i).to_stderr
      end
    end
  end
end
