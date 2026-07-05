# frozen_string_literal: true

require "tmpdir"
require "ostruct"

module Fatty
  RSpec.describe KeyTestSession do

    def init_keytest_session(session, terminal_name: "xterm-256color")
      output_rect = OpenStruct.new(row: 0, rows: 10, cols: 80)
      screen = instance_double(Fatty::Screen, output_rect: output_rect)
      renderer = instance_double(Fatty::Renderer, screen: screen, theme_version: 0)
      env = { terminal: terminal_name }
      terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer, env: env)
      keymap = instance_double(Fatty::KeyMap, bindings_for: {})
      allow(Fatty::KeyMap).to receive(:active).and_return(keymap)
      session.init(terminal: terminal)
    end

    describe "#initialize" do
      it "creates an output session" do
        session = Fatty::KeyTestSession.new

        expect(session.id).to eq(:keytest)
        expect(session.output_session).to be_a(Fatty::OutputSession)
      end
    end

    describe "#init" do
      it "initializes and registers its output session" do
        session = Fatty::KeyTestSession.new

        commands = init_keytest_session(session)

        expect(commands.map(&:action)).to eq(
          [
            :register_session,
            :resize,
            :set_mode,
            :begin_command,
            :append,
            :show,
          ],
        )

        expect(commands.first.payload[:session]).to be(session.output_session)
        expect(commands[1].target).to eq(session.output_session.id)
        expect(commands[2].payload[:mode]).to eq(:scrolling)
        expect(commands[4].payload[:text]).to include("Key test mode")
        expect(commands.last.target).to eq(:status)
        expect(commands.last.payload[:text]).to include("xterm-256color")
      end
    end

    describe "#update" do
      it "reports an unbound key and records its suggestion" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        ev = Fatty::KeyEvent.new(key: :f99, raw: 999)

        commands = update(session, :key, event: ev)

        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.payload[:text]).to include("Key report")
        expect(commands.first.payload[:text]).to include("Suggested keybindings")
        expect(commands.first.payload[:text]).to include("No action is bound to f99")
        expect(commands.last.target).to eq(:status)
      end

      it "reports an uncoded key and records a keydef suggestion" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session, terminal_name: "tmux")

        ev = Fatty::KeyEvent.new(key: 652, raw: 652)

        commands = update(session, :key, event: ev)

        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.first.payload[:text]).to include("Key report")
        expect(commands.first.payload[:text]).to include("No key name is associated with keycode 652")
        expect(commands.first.payload[:text]).to include("tmux:")
      end

      it "reports a bound key without a suggestion" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        allow(Fatty::KeyMap.active)
          .to receive(:bindings_for)
          .and_return(input: :accept_line)
        ev = Fatty::KeyEvent.new(key: :enter, raw: 10)
        commands = update(session, :key, event: ev)
        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.first.payload[:text]).to include("(BOUND)")
        expect(commands.first.payload[:text]).to include("bindings:")
        expect(commands.first.payload[:text]).not_to include("No action is bound")
        expect(commands.first.payload[:text]).not_to include("No key name is associated")
      end

      it "quits on q without writing suggestions when none have been recorded" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        commands = update(session, :key, event: key(:q, text: "q"))
        expect(commands.map(&:action)).to eq(
          [:append, :clear, :pop_modal, :show],
        )
        expect(commands.first.payload[:text]).to include("Leaving key test mode")
        expect(commands[1].target).to eq(:status)
        expect(commands.last.payload[:text]).to include("KeyTest suggestions written to ")
      end

      it "quits on escape" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        commands = update(session, :key, event: key(:escape))
        expect(commands.map(&:action)).to eq(
          [:append, :clear, :pop_modal, :show],
        )
      end

      it "quits on C-g" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        commands = update(session, :key, event: key(:g, ctrl: true))
        expect(commands.map(&:action)).to eq(
          [:append, :clear, :pop_modal, :show],
        )
      end

      it "writes unique suggestions before quitting" do
        Dir.mktmpdir("fatty_keytest_spec") do |dir|
          session = Fatty::KeyTestSession.new(output_dir: dir)
          init_keytest_session(session, terminal_name: "tmux")

          allow(Dir).to receive(:tmpdir).and_return(dir)
          allow(Time).to receive(:now).and_return(Time.new(2026, 6, 15, 3, 42, 52))

          ev = Fatty::KeyEvent.new(key: 652, raw: 652)
          update(session, :key, event: ev)
          update(session, :key, event: ev)
          commands = update(session, :key, event: key(:q, text: "q"))

          files = Dir.glob(File.join(dir, "fatty-keytest-*.yml"))
          expect(files.length).to eq(1)

          content = File.read(files.first)
          expect(content.scan("No key name is associated with keycode 652").length).to eq(1)
          # expect(commands.last.payload[:text]).to include(path)
        end
      end

      it "ignores unknown commands" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        expect(update(session, :bogus)).to eq([])
      end

      it "reports an unbound mouse event and records its suggestion" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)
        ev = Fatty::MouseEvent.new(button: :scroll_down, ctrl: true, x: 10, y: 3)
        commands = update(session, :key, event: ev)
        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.payload[:text]).to include("Mouse report")
        expect(commands.first.payload[:text]).to include("Suggested keybindings")
        expect(commands.first.payload[:text]).to include("No action is bound to C-scroll_down")
        expect(commands.first.payload[:text]).to include("- button: scroll_down")
        expect(commands.first.payload[:text]).to include("  ctrl: true")
      end

      it "reports a bound mouse event without a suggestion" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)
        allow(Fatty::KeyMap.active)
          .to receive(:bindings_for)
                .and_return(paging: :page_down)
        ev = Fatty::MouseEvent.new(button: :scroll_down, ctrl: true, x: 10, y: 3)
        commands = update(session, :key, event: ev)
        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.first.payload[:text]).to include("Mouse report")
        expect(commands.first.payload[:text]).to include("(BOUND)")
        expect(commands.first.payload[:text]).to include("bindings:")
        expect(commands.first.payload[:text]).not_to include("No action is bound")
      end

      it "does not treat a mouse event as a quit key" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)
        ev = Fatty::MouseEvent.new(button: :left_clicked, ctrl: true, x: 10, y: 3)
        commands = update(session, :key, event: ev)
        expect(commands.map(&:action)).to eq([:append, :show])
        expect(commands.map(&:action)).not_to include(:pop_modal)
      end
    end

    describe "#view" do
      it "delegates to the output session" do
        session = Fatty::KeyTestSession.new
        init_keytest_session(session)

        expect(session.output_session).to receive(:view)

        session.view
      end
    end

    describe "#close" do
      it "closes the output session" do
        session = Fatty::KeyTestSession.new

        expect(session.output_session).to receive(:close)

        expect(session.close).to be_nil
      end
    end
  end
end
