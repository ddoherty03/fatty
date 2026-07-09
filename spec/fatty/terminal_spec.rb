# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Terminal do
    class TerminalSpecContext
      attr_reader :truecolor

      def initialize(truecolor: false)
        @truecolor = truecolor
      end
    end

    class TerminalSpecSession
      attr_reader :id, :updates, :views, :ticks, :inits, :closes, :persists
      attr_accessor :init_commands, :update_commands, :tick_result

      def initialize(id:)
        @id = id
        @updates = []
        @views = 0
        @ticks = 0
        @inits = 0
        @closes = 0
        @persists = 0
        @init_commands = []
        @update_commands = []
        @tick_result = false
      end

      def init(terminal:)
        @terminal = terminal
        @inits += 1
        init_commands
      end

      def update(command)
        updates << command
        update_commands
      end

      def view
        @views += 1
      end

      def tick
        @ticks += 1
        tick_result
      end

      def close
        @closes += 1
      end

      def persist!
        @persists += 1
      end
    end

    class TerminalSpecRenderer
      attr_accessor :screen
      attr_reader :begins, :finishes, :invalidations, :themes, :restored_fields

      def initialize
        @begins = 0
        @finishes = 0
        @invalidations = 0
        @themes = []
        @restored_fields = []
      end

      def begin_frame
        @begins += 1
      end

      def finish_frame
        @finishes += 1
      end

      def invalidate!
        @invalidations += 1
      end

      def apply_theme!(theme)
        @themes << theme
      end

      def restore_cursor(field)
        @restored_fields << field
      end

      def context
        @context ||= TerminalSpecContext.new(truecolor: false)
      end

      def hide_cursor
      end

      def show_cursor
      end
    end

    def terminal
      terminal = Fatty::Terminal.new
      terminal.instance_variable_set(:@renderer, TerminalSpecRenderer.new)
      terminal.instance_variable_set(:@sessions, [])
      terminal.instance_variable_set(:@sessions_by_id, {})
      terminal.instance_variable_set(:@modal_stack, [])
      terminal.instance_variable_set(:@running, false)

      ss = install_session(
        terminal,
        TerminalSpecSession.new(id: :status),
      )
      terminal.instance_variable_set(:@status_session, ss)
      as = install_session(
        terminal,
        TerminalSpecSession.new(id: :alert),
      )
      terminal.instance_variable_set(:@alert_session, as)

      terminal
    end

    def install_session(terminal, session, focus: false)
      terminal.instance_variable_get(:@sessions) << session
      terminal.instance_variable_get(:@sessions_by_id)[session.id] = session
      terminal.instance_variable_set(:@focused_session, session) if focus
      session
    end

    before do
      allow(::Curses).to receive(:curs_set)
    end

    describe "#inspect" do
      it "summarizes prompt, history, session count, and active session" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect(t.inspect).to include("Terminal:")
        expect(t.inspect).to include("sessions size: 3")
        expect(t.inspect).to include("active: #{shell.id}")
      end
    end

    describe "#to_s" do
      it "returns inspect" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect(t.to_s).to eq(t.inspect)
      end
    end

    describe "#go" do
      it "starts curses, applies events, renders dirty frames, and stops curses" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        event_source = double("EventSource", next_event: Fatty::Command.session(:active, :custom))
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:event_source).and_return(event_source)
        allow(t).to receive(:render_frame).and_call_original

        shell.update_commands = [Fatty::Command.terminal(:quit)]

        t.go

        expect(t).to have_received(:start_curses!)
        expect(t).to have_received(:install_default_sessions!)
        expect(event_source).to have_received(:next_event)
        expect(shell.updates.map(&:action)).to eq([:custom])
        expect(t).to have_received(:render_frame).at_least(:once)
        expect(t).to have_received(:stop_curses!)
        expect(t.running?).to be(false)
      end

      it "ticks and renders even when there is no event" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        event_source = double("EventSource", next_event: nil)

        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:event_source).and_return(event_source)
        allow(t).to receive(:render_frame)

        shell.tick_result = true
        allow(shell).to receive(:tick) do
          t.apply_command(Fatty::Command.terminal(:quit))
          true
        end

        t.go

        expect(shell).to have_received(:tick)
        expect(t).to have_received(:render_frame).at_least(:once)
        expect(t).to have_received(:stop_curses!)
      end

      it "stops curses even when the loop raises" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        event_source = double("EventSource")

        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:event_source).and_return(event_source)
        allow(event_source).to receive(:next_event).and_raise(RuntimeError, "boom")

        expect { t.go }.to raise_error(RuntimeError, "boom")
        expect(t).to have_received(:stop_curses!)
      end

      it "defers scrolling renders before the throttle interval expires" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        event_source = double("EventSource", next_event: nil)

        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive_messages(event_source: event_source, scrolling_output?: true)
        allow(t).to receive(:render_frame)
        allow(t.renderer.context).to receive(:truecolor).and_return(false)
        times = [0.0, 0.0, 0.0, 0.01, 0.01]
        allow(Process).to receive(:clock_gettime) { times.shift || 0.01 }
        allow(shell).to receive(:tick) do
          t.apply_command(Fatty::Command.terminal(:quit))
          true
        end

        t.go
        expect(t).to have_received(:render_frame).once
      end

      it "renders deferred scrolling output after the throttle interval" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        event_source = double("EventSource", next_event: nil)

        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive_messages(event_source: event_source, scrolling_output?: true)
        allow(t).to receive(:render_frame)
        allow(t.renderer.context).to receive(:truecolor).and_return(false)

        times = [0.0, 0.0, 0.01, 0.20]
        allow(Process).to receive(:clock_gettime) { times.shift || 0.20 }

        ticks = 0
        allow(shell).to receive(:tick) do
          ticks += 1
          case ticks
          when 1
            true
          when 2
            false
          else
            t.apply_command(Fatty::Command.terminal(:quit))
            false
          end
        end
        t.go
        expect(t).to have_received(:render_frame).at_least(2).times
      end

      it "logs stop_curses! failures during cleanup" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!).and_raise(StandardError, "stop failed")
        allow(t).to receive(:persist_sessions!)
        allow(t).to receive(:event_source).and_raise(StandardError, "boom")
        allow(Fatty).to receive(:error)

        expect { t.go }.to raise_error(StandardError, "boom")
        expect(Fatty).to have_received(:error).with(/stop_curses! failed/, tag: :terminal)
      end

      it "logs persist_sessions! failures during cleanup" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        allow(t).to receive(:install_default_sessions!)
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:persist_sessions!).and_raise(StandardError, "persist failed")
        allow(t).to receive(:event_source).and_raise(StandardError, "boom")
        allow(Fatty).to receive(:error)

        expect { t.go }.to raise_error(StandardError, "boom")
        expect(Fatty).to have_received(:error).with(/persist_sessions! failed/, tag: :terminal)
      end
    end

    describe "#running?" do
      it "reflects running state" do
        t = terminal

        expect(t.running?).to be(false)

        t.instance_variable_set(:@running, true)

        expect(t.running?).to be(true)
      end
    end

    describe "#modal_active?" do
      it "is false without a modal and true with a modal" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        modal = TerminalSpecSession.new(id: :modal)

        expect(t.modal_active?).to be(false)

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal))

        expect(t.modal_active?).to be(true)

        t.apply_command(Fatty::Command.terminal(:pop_modal))

        expect(t.modal_active?).to be(false)
      end
    end

    describe "#apply_command" do
      it "raises for nil command" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect { t.apply_command(nil) }
          .to raise_error(ArgumentError, "expected command, got nil")
      end

      it "routes session commands to the addressed session" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        command = Fatty::Command.session(:shell, :custom, value: 1)

        t.apply_command(command)

        expect(shell.updates).to eq([command])
      end

      it "applies commands returned by sessions" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        alert = install_session(t, TerminalSpecSession.new(id: :alert))
        shell.update_commands = [
          Fatty::Command.session(:alert, :show, text: "hello", level: :info),
        ]

        t.apply_command(Fatty::Command.session(:shell, :custom))

        expect(alert.updates.map(&:action)).to eq([:show])
      end

      it "routes :active to the focused session when no modal is active" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        command = Fatty::Command.session(:active, :custom)

        t.apply_command(command)

        expect(shell.updates).to eq([command])
      end

      it "routes :active to the top modal when a modal is active" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        modal = TerminalSpecSession.new(id: :modal)

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal))
        command = Fatty::Command.session(:active, :custom)
        t.apply_command(command)

        expect(shell.updates).to eq([])
        expect(modal.updates).to eq([command])
      end

      it "routes :focused to the focused session even when a modal is active" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        modal = TerminalSpecSession.new(id: :modal)

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal))
        command = Fatty::Command.session(:focused, :custom)
        t.apply_command(command)

        expect(shell.updates).to eq([command])
        expect(modal.updates).to eq([])
      end

      it "clears status and alert before user key commands" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        status = install_session(t, TerminalSpecSession.new(id: :status))
        alert = install_session(t, TerminalSpecSession.new(id: :alert))
        key = Fatty::KeyEvent.new(key: :a)

        t.apply_command(Fatty::Command.session(:active, :key, event: key))

        expect(status.updates.map(&:action)).to eq([:clear])
        expect(alert.updates.map(&:action)).to eq([:clear])
        expect(shell.updates.map(&:action)).to eq([:key])
      end

      it "does not clear status and alert for resize key commands" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        status = install_session(t, TerminalSpecSession.new(id: :status))
        alert = install_session(t, TerminalSpecSession.new(id: :alert))

        t.apply_command(Fatty::Command.session(:active, :resize))

        expect(status.updates).to eq([])
        expect(alert.updates).to eq([])
        expect(shell.updates.map(&:action)).to eq([:resize])
      end

      it "registers a session with a terminal command" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        extra = TerminalSpecSession.new(id: :extra)
        command = Fatty::Command.session(:extra, :custom)

        t.apply_command(Fatty::Command.terminal(:register_session, session: extra))
        t.apply_command(command)

        expect(extra.updates).to eq([command])
      end

      it "sets running false for quit" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        t.instance_variable_set(:@running, true)

        t.apply_command(Fatty::Command.terminal(:quit))

        expect(t.running?).to be(false)
        expect(shell.persists).to eq(1)
      end

      it "sends modal-owner commands and applies returned commands" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        alert = install_session(t, TerminalSpecSession.new(id: :alert))
        owner = TerminalSpecSession.new(id: :owner)
        modal = TerminalSpecSession.new(id: :modal)
        owner.update_commands = [
          Fatty::Command.session(:alert, :show, text: "changed", role: :info),
        ]
        owner_command = Fatty::Command.session(:owner, :popup_changed, item: "One")

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal, owner: owner))
        t.apply_command(Fatty::Command.terminal(:send_modal_owner, command: owner_command))

        expect(owner.updates).to eq([owner_command])
        expect(alert.updates.map(&:action)).to eq([:show])
      end

      it "raises for an unknown terminal command" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect {
          t.apply_command(Fatty::Command.terminal(:bogus))
        }.to raise_error(ArgumentError, /unknown terminal command/)
      end

      it "raises for an unknown session id" do
        t = terminal
        install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect {
          t.apply_command(Fatty::Command.session(:missing, :custom))
        }.to raise_error(ArgumentError, /no session registered/)
      end
    end

    describe "#render_frame" do
      it "renders the focused session, top modal, status, and alert inside a renderer frame" do
        t = terminal
        renderer = t.renderer
        shell = install_session(
          t,
          TerminalSpecSession.new(id: :shell),
          focus: true,
        )
        status = t.status_session
        alert = t.alert_session
        modal = TerminalSpecSession.new(id: :modal)

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal))
        t.render_frame

        expect(renderer.begins).to eq(1)
        expect(shell.views).to eq(1)
        expect(modal.views).to eq(1)
        expect(status.views).to eq(1)
        expect(alert.views).to eq(1)
        expect(renderer.finishes).to eq(1)
      end
    end

    describe "#tick_active_session" do
      it "ticks the focused session when no modal is active" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)

        expect(t.tick_active_session).to be(false)
        expect(shell.ticks).to eq(1)
      end

      it "ticks the modal session when a modal is active" do
        t = terminal
        shell = install_session(t, TerminalSpecSession.new(id: :shell), focus: true)
        modal = TerminalSpecSession.new(id: :modal)
        modal.tick_result = true

        t.apply_command(Fatty::Command.terminal(:push_modal, session: modal))

        expect(t.tick_active_session).to be(true)
        expect(shell.ticks).to eq(0)
        expect(modal.ticks).to eq(1)
      end
    end

    describe "#go preflight" do
      def write_xdg_config(xdg_home, app:, name:, content:)
        dir = File.join(xdg_home, app)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "#{name}.yml"), content)
      end

      around do |example|
        Dir.mktmpdir("fatty_spec_xdg") do |tmp|
          old_xdg = ENV["XDG_CONFIG_HOME"]
          old_reader = Fatty::Config.reader
          old_progname = Fatty::Config.progname
          old_logger = Fatty::Logger.logger

          ENV["XDG_CONFIG_HOME"] = tmp
          Fatty::Config.progname = "fatty"
          Fatty::Config.reader = nil
          Fatty::Logger.logger = nil

          example.run
        ensure
          Fatty::Config.reader = old_reader
          Fatty::Config.progname = old_progname
          Fatty::Logger.logger = old_logger
          ENV["XDG_CONFIG_HOME"] = old_xdg
        end
      end

      it "prints a configuration error and exits 1 on parse error" do
        write_xdg_config(
          ENV.fetch("XDG_CONFIG_HOME"),
          app: "fatty",
          name: "config",
          content: "log: [broken",
        )
        t = Fatty::Terminal.new

        expect {
          expect { t.go }.to raise_error(SystemExit) { |error|
            expect(error.status).to eq(1)
          }
        }.to output(/YAML parse error/).to_stderr
      end

      it "includes file and location information in parse errors when available" do
        write_xdg_config(
          ENV.fetch("XDG_CONFIG_HOME"),
          app: "fatty",
          name: "config",
          content: "log: [broken",
        )
        t = Fatty::Terminal.new

        expect {
          expect { t.go }.to raise_error(SystemExit)
        }.to output(/at line \d+, column \d+/i).to_stderr
      end

      it "configures app-specific config before preflight reads config" do
        terminal = Fatty::Terminal.new(
          app_name: "byr",
          app_config_dir: "/tmp/byr/fatty",
        )

        allow(Fatty::Config).to receive(:install_defaults!)
        allow(Fatty::Config).to receive(:config).and_return({})
        allow(Fatty::Logger).to receive(:configure)
        allow(Fatty::Config).to receive(:keydefs).and_return({})
        allow(Fatty::Config).to receive(:keybindings).and_return([])
        allow(Fatty::Themes::Manager).to receive(:load!)

        terminal.send(:preflight!)

        expect(Fatty::Config.app_name).to eq("byr")
        expect(Fatty::Config.app_config_dir).to eq("/tmp/byr/fatty")
      end
    end

    describe "#go default sessions" do
      it "passes history_ctx to the default shell session" do
        stop_error = Class.new(StandardError)
        history_ctx = -> { { pwd: "/tmp/demo" } }
        t = Fatty::Terminal.new(history_ctx: history_ctx)
        shell = nil
        event_source = double("EventSource")

        allow(t).to receive(:preflight!)
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:persist_sessions!)
        allow(t).to receive(:render_frame)
        allow(t).to receive(:event_source).and_return(event_source)
        allow(event_source).to receive(:next_event).and_raise(stop_error)
        allow(t).to receive(:install_session) do |session, **_kwargs|
          shell = session if session.is_a?(Fatty::ShellSession)
          []
        end

        expect { t.go }.to raise_error(stop_error)

        expect(shell).to be_a(Fatty::ShellSession)
        expect(shell.field.send(:resolve_history_ctx)).to eq({ pwd: "/tmp/demo" })
      end
    end

    describe "#suspend" do
      it "stops curses, yields, restarts curses, refreshes layout, and renders" do
        t = terminal
        yielded = false

        allow(t).to receive(:stop_curses!)
        allow(t).to receive(:start_curses!)
        allow(t).to receive(:refresh_layout!)
        allow(t).to receive(:render_frame)

        t.suspend do
          yielded = true
        end

        expect(yielded).to be(true)
        expect(t).to have_received(:stop_curses!)
        expect(t).to have_received(:start_curses!)
        expect(t).to have_received(:refresh_layout!)
        expect(t).to have_received(:render_frame)
      end
    end
  end
end
