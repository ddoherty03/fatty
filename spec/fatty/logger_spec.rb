# frozen_string_literal: true

require "tmpdir"
require "json"

module Fatty
  RSpec.describe Logger do
    let(:progname) { 'fatty_spec' }

    around do |ex|
      # Preserve global logger + env, since Fatty::Logger is module-global.
      old_logger = Logger.logger
      old_xdg = ENV["XDG_STATE_HOME"]

      Dir.mktmpdir("fatty_log_spec") do |dir|
        ENV["XDG_STATE_HOME"] = dir
        Fatty::Config.progname = progname
        ex.run
      end
    ensure
      Logger.logger = old_logger
      ENV["XDG_STATE_HOME"] = old_xdg
    end

    def read_lines(path)
      File.exist?(path) ? File.read(path).lines : []
    end

    describe ".configure" do
      it "creates the log file under XDG_STATE_HOME when no config path is set" do
        # Ensure config doesn't specify a path
        allow(Fatty::Config).to receive(:config).and_return({ log: { level: 'info', format: 'json' } })

        logger = Logger.configure
        expect(logger).to be_a(::Logger)

        path = File.join(ENV.fetch("XDG_STATE_HOME"), "#{progname}", "#{progname}.log")
        expect(File.exist?(path)).to be(true)
        expect(File.readable?(path)).to be(true)
        expect(File.writable?(path)).to be(true)
      end

      it "uses the XDG_STATE_HOME path when set" do
        custom = File.join(ENV.fetch("XDG_STATE_HOME"), "custom_logs", "ft.log")
        allow(Fatty::Config).to receive(:config).and_return(log: { file: custom })

        logger = Fatty::Logger.configure

        expect(logger).to be_a(::Logger)
        expect(File.exist?(custom)).to be(true)
        expect(File.readable?(custom)).to be(true)
        expect(File.writable?(custom)).to be(true)
      end

      it "falls back to ~/.state/fatty/fatty.log when no config path and no XDG_STATE_HOME" do
        allow(Fatty::Config).to receive(:config).and_return({})

        old_xdg  = ENV.delete("XDG_STATE_HOME")
        old_home = ENV["HOME"]

        Dir.mktmpdir("fatty_home") do |tmp_home|
          ENV["HOME"] = tmp_home

          logger = Fatty::Logger.configure
          expect(logger).to be_a(::Logger)

          expected = File.expand_path("~/.state/#{progname}/#{progname}.log")
          expect(expected).to start_with(tmp_home)

          expect(File.exist?(expected)).to be(true)
          expect(File.readable?(expected)).to be(true)
          expect(File.writable?(expected)).to be(true)
        end
      ensure
        ENV["HOME"] = old_home
        ENV["XDG_STATE_HOME"] = old_xdg if old_xdg
      end

      it "returns nil logger and Logger.log becomes a no-op when the log file is not readable" do
        custom = File.join(ENV.fetch("XDG_STATE_HOME"), "custom_logs", "ft.log")

        allow(Fatty::Config).to receive(:config).and_return(log: { file: custom })

        # Simulate unreadable file
        allow(File).to receive(:readable?) do |p|
          p == File.expand_path(custom) ? false : File.readable?(p)
        end

        allow(File).to receive(:writable?) do |p|
          p == File.expand_path(custom) ? true : File.writable?(p)
        end

        logger = Fatty::Logger.configure

        expect(logger).to be_nil
        expect(Fatty::Logger.logger).to be_nil

        # Should not raise, should not write
        expect {
          Fatty::Logger.log(:should_be_ignored, foo: 1)
        }.not_to raise_error

        expect(File.exist?(custom)).to be(true)
        expect(File.read(custom)).to eq("")
      end

      it "returns nil logger and Logger.log becomes a no-op when the log file is not writable" do
        custom = File.join(ENV.fetch("XDG_STATE_HOME"), "custom_logs", "ft.log")

        allow(Fatty::Config).to receive(:config).and_return(log: { file: custom })

        allow(File).to receive(:readable?) do |p|
          p == File.expand_path(custom) ? true : File.readable?(p)
        end

        allow(File).to receive(:writable?) do |p|
          p == File.expand_path(custom) ? false : File.writable?(p)
        end

        logger = Fatty::Logger.configure
        expect(logger).to be_nil
        expect(Fatty::Logger.logger).to be_nil

        expect {
          Fatty::Logger.log(:should_be_ignored, foo: 1)
        }.not_to raise_error

        expect(File.exist?(custom)).to be(true)
        expect(File.read(custom)).to eq("")
      end

      it "sets logger level and formatter based on config" do
        allow(Fatty::Config).to receive(:config).and_return({ log: { level: 'warn', format: 'json' } })

        logger = Logger.configure
        expect(logger.level).to eq(::Logger::WARN)
        expect(logger.progname).to eq("fatty_spec")
        expect(logger.formatter).to be_a(Fatty::Logger::JsonFormatter)
      end
    end

    describe "TextFormatter" do
      it "uses TextFormatter when json: false" do
        allow(Fatty::Config).to receive(:config).and_return({ log: { level: 'info', format: 'text' } })

        logger = Logger.configure
        expect(logger.formatter).to be_a(Fatty::Logger::TextFormatter)
      end

      it "formats as: <iso8601> <SEV> <progname> <msg>\\n" do
        fmt = Logger::TextFormatter.new
        t   = Time.utc(2026, 2, 3, 12, 34, 56, 123_456) # stable

        line = fmt.call("INFO", t, "fatty_spec", "hello")

        expect(line).to start_with("2026-02-03T12:34:56.123456Z INFO fatty_spec hello")
        expect(line).to end_with("\n")
      end

      it "writes plain text lines to the log file" do
        path = File.join("/tmp", "text_#{$$}.log")
        allow(Fatty::Config).to receive(:progname).and_return("fatty_spec")
        allow(Fatty::Config).to receive(:config).and_return({
                                                                log: {
                                                                  file: path,
                                                                  level: :debug,
                                                                  format: :text,
                                                                  tags: [:all],
                                                                },
                                                              })

        Logger.configure
        Logger.log("evt", level: :info, tag: :render, foo: 1, bar: [2, 4, 6])

        lines = File.readlines(path)
        expect(lines.first).to match(/INFO.*fatty_spec/)
        expect(lines.first).to include("[render]")
        expect(lines.first).to include("evt")
        expect(lines.last).to include("foo:")
        expect(lines.last).to include("1")
        expect(lines.last).to include("bar:")
        expect(lines.last).to include("2")
        expect(lines.last).to include("6")
      end
    end

    describe ".severity" do
      it "maps known symbols to ::Logger constants and defaults to DEBUG" do
        expect(Logger.severity(:debug)).to eq(::Logger::DEBUG)
        expect(Logger.severity(:info)).to eq(::Logger::INFO)
        expect(Logger.severity(:warn)).to eq(::Logger::WARN)
        expect(Logger.severity(:error)).to eq(::Logger::ERROR)
        expect(Logger.severity(:fatal)).to eq(::Logger::FATAL)
        expect(Logger.severity(:whatever)).to eq(::Logger::DEBUG)
      end
    end

    describe ".log (tag filtering + payload)" do
      it "writes a JSON line including envelope fields and payload fields when tag is allowed" do
        allow(Fatty::Config).
          to receive(:config)
               .and_return({ log: { tags: [:all] } })

        Logger.configure
        path = File.join(ENV.fetch("XDG_STATE_HOME"), progname, "#{progname}.log")
        Logger.log(:hello, level: :info, tag: :render, foo: 123)

        lines = read_lines(path)
        expect(lines).not_to be_empty

        rec = JSON.parse(lines.last)
        # envelope
        expect(rec).to include("t", "sev", "prog")
        expect(rec["prog"]).to eq("fatty_spec")
        expect(rec["sev"]).to eq("INFO")

        # payload from Fatty.log
        expect(rec["event"]).to eq("hello")
        expect(rec["tag"]).to eq("render")
        expect(rec["foo"]).to eq(123)
      end

      it "does not log tagged messages when tag is not in allow-list and :all is absent" do
        allow(Fatty::Config)
          .to receive(:config)
                .and_return({
                              log: { tags: [:keybinding] }
                            })
        Logger.configure
        path = File.join(ENV.fetch("XDG_STATE_HOME"), "fatty", "fatty.log")
        Logger.log(:nope, level: :info, tag: :render, x: 1)

        # file exists, but no line added (or at least last line isn't ours)
        expect(read_lines(path)).to be_empty
      end

      it "logs untagged messages even when tags are restricted" do
        allow(Fatty::Config)
          .to receive(:config)
                .and_return({
                              log: { tags: [:keybinding] }
                            })

        Logger.configure
        path = File.join(ENV.fetch("XDG_STATE_HOME"), progname, "#{progname}.log")

        Logger.log(:untagged_event, level: :info, foo: "bar")

        rec = JSON.parse(read_lines(path).last)
        expect(rec["event"]).to eq("untagged_event")
        expect(rec["tag"]).to be_nil
        expect(rec["foo"]).to eq("bar")
      end
    end

    describe Fatty::Logger::JsonFormatter do
      it "merges JSON msg hashes into the envelope" do
        fmt = Logger::JsonFormatter.new
        msg = { event: "x", tag: "y", n: 1 }.to_json

        line = fmt.call("INFO", Time.at(0).utc, "fatty_spec", msg)
        rec = JSON.parse(line)

        expect(rec["t"]).to be_a(String)
        expect(rec["sev"]).to eq("INFO")
        expect(rec["prog"]).to eq("fatty_spec")

        expect(rec["event"]).to eq("x")
        expect(rec["tag"]).to eq("y")
        expect(rec["n"]).to eq(1)
      end

      it "stores non-JSON messages under msg" do
        fmt = Logger::JsonFormatter.new
        line = fmt.call("INFO", Time.at(0).utc, "fatty_spec", "hello world")
        rec = JSON.parse(line)

        expect(rec["msg"]).to eq("hello world")
      end
    end

    describe ".log error handling" do
      it "never raises if the underlying logger blows up" do
        allow(Fatty::Config).to receive(:config).and_return({ log: { tags: [:all] } })
        Logger.configure

        # Force logger.add to raise
        allow(Logger.logger).to receive(:add).and_raise(StandardError, "boom")
        expect {
          Logger.log(:evt, tag: :render, a: 1)
        }.not_to raise_error
      end
    end
  end
end
