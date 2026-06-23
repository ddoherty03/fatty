# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Fatty
  RSpec.describe ShellSession do
    def init_shell_session(session, modal_active: false, rows: 5, cols: 80, theme_version: 0)
      output_rect = { row: 0, rows: rows, cols: cols }
      screen = instance_double(Fatty::Screen, output_rect: output_rect)
      renderer = instance_double(
        Fatty::Renderer,
        screen: screen,
        theme_version: theme_version,
      )
      terminal = instance_double(
        Fatty::Terminal,
        screen: screen,
        renderer: renderer,
        modal_active?: modal_active,
      )
      allow(terminal).to receive(:apply_command)
      session.init(terminal: terminal)
      session
    end

    describe "#init" do
      it "initializes and registers its output session" do
        session = Fatty::ShellSession.new
        terminal = instance_double(Fatty::Terminal)

        expect(session.output_session).to receive(:init).with(terminal: terminal).and_call_original

        commands = session.init(terminal: terminal)
        expect(commands.map(&:action)).to eq([:register_session, :resize])
        expect(commands.first.payload[:session]).to be(session.output_session)
        expect(commands.last.target).to eq(session.output_session.id)
      end
    end

    describe "#update" do
      it "handles :terminal_paste by inserting normalized text into the field" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = update(session, :terminal_paste, text: "hello\nworld\n")

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("hello world ")
      end

      it "handles :popup_result for history search" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = update(
          session,
          :popup_result,
          kind: :history_search,
          item: "bundle exec rspec",
        )

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("bundle exec rspec")
      end

      it "handles :popup_result for completion" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("st")

        commands = update(
          session,
          :popup_result,
          kind: :completion,
          item: "git status",
        )

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("git status ")
      end

      it "routes keys to the output session when the pager is active" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        allow(session.output_session)
          .to receive(:pager_active?)
                .and_return(true)

        ev = key(:pagedown)

        commands = update(session, :key, event: ev)

        expect(commands.length).to eq(1)
        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.action).to eq(:key)
        expect(commands.first.payload[:event]).to be(ev)
      end

      # it "handles resize keys" do
      #   session = Fatty::ShellSession.new
      #   init_shell_session(session)

      #   commands = update(session, :key, event: key(:resize))

      #   expect(commands.length).to eq(1)
      #   expect(commands.first.target).to eq(:terminal)
      #   expect(commands.first.action).to eq(:resize)
      # end

      it "handles enter by submitting the current line" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("clear")

        commands = update(session, :key, event: key(:enter))

        expect(commands.map(&:target)).to eq([session.output_session.id, :alert])
        expect(commands.map(&:action)).to eq([:clear, :clear])
      end

      it "handles return by submitting the current line" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("quit")

        commands = update(session, :key, event: key(:return))

        expect(commands.length).to eq(1)
        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:quit)
      end

      it "alerts for an unbound key" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = update(session, :key, event: key(:f99))

        expect(commands.length).to eq(1)
        expect(commands.first.target).to eq(:alert)
        expect(commands.first.action).to eq(:show)
        expect(commands.first.payload[:alert].level).to eq(:warn)
      end

      it "ignores non-KeyEvent key payloads" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = update(session, :key, event: Object.new)

        expect(commands).to eq([])
      end

      it "ignores unknown commands" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = update(session, :bogus)

        expect(commands).to eq([])
      end
    end

    describe "#view" do
      it "renders output and input when input is not suppressed" do
        session = Fatty::ShellSession.new
        init_shell_session(session, modal_active: false)

        expect(session.output_session).to receive(:view)
        expect(session.renderer).to receive(:show_cursor)
        expect(session.renderer)
          .to receive(:render_input_field)
                .with(session.field)
        expect(session.renderer)
          .to receive(:restore_cursor)
                .with(session.field)
        session.view
      end

      it "renders output and clears input when a modal is active" do
        session = Fatty::ShellSession.new
        init_shell_session(session, modal_active: true)
        allow(::Curses).to receive(:curs_set)

        expect(session.output_session).to receive(:view)
        expect(session.renderer).to receive(:hide_cursor)
        expect(session.renderer).to receive(:clear_input_field)
        expect(session.renderer).not_to receive(:render_input_field)
        session.view
      end
    end

    describe "#tick" do
      it "delegates to output_session" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        expect(session.output_session).to receive(:tick).and_return(true)
        expect(session.tick).to be(true)
      end
    end

    describe "#pager_active?" do
      it "delegates to output_session" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        allow(session.output_session).to receive(:pager_active?).and_return(true)
        expect(session.pager_active?).to be(true)
      end
    end

    describe "#persist!" do
      it "persists history" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        allow(session.history).to receive(:save!)

        session.persist!

        expect(session.history).to have_received(:save!)
      end
    end

    describe "actions" do
      it "submits an empty line without commands" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        expect(apply_action(session, :submit_line)).to eq([])
      end

      it "submits quit as a terminal quit command" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("quit")

        commands = apply_action(session, :submit_line)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:quit)
      end

      it "submits clear as output and alert clear commands" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("clear")

        commands = apply_action(session, :submit_line)

        expect(commands.map(&:target)).to eq([session.output_session.id, :alert])
        expect(commands.map(&:action)).to eq([:clear, :clear])
      end

      it "submits a line through the accept callback" do
        callback = lambda do |_line, env|
          env.append("callback output\n")
          "result output\n"
        end

        session = Fatty::ShellSession.new(on_accept: callback)
        init_shell_session(session)

        session.field.buffer.replace("hello")

        commands = apply_action(session, :submit_line)
        expect(session.terminal)
          .to have_received(:apply_command)
                .with(have_attributes(action: :begin_command))
        expect(commands.map(&:action))
          .to eq([:append, :append, :finish_command])
        expect(commands[0].payload[:text]).to eq("callback output\n")
        expect(commands[1].payload[:text]).to eq("result output\n")
      end

      it "submits default command output" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("echo hello")
        commands = apply_action(session, :submit_line)
        expect(session.terminal)
          .to have_received(:apply_command)
                .with(have_attributes(action: :begin_command))
        expect(commands.map(&:action))
          .to eq([:append, :append, :finish_command])
        expect(commands[0].payload[:text]).to eq("$ echo hello\n")
      end

      it "submits command arrays returned by the accept callback" do
        callback = lambda do |_line, env|
          [
            env.append("one\n"),
            env.append("two\n"),
          ]
        end
        session = Fatty::ShellSession.new(on_accept: callback)
        init_shell_session(session)

        session.field.buffer.replace("hello")
        commands = apply_action(session, :submit_line)
        expect(session.terminal)
          .to have_received(:apply_command)
                .with(have_attributes(action: :begin_command))
        expect(commands.map(&:action))
          .to eq([:append, :append, :finish_command])
        expect(commands[0].payload[:text]).to eq("one\n")
        expect(commands[1].payload[:text]).to eq("two\n")
      end

      it "submits and switches output to scrolling mode" do
        callback = lambda do |_line, env|
          env.append("callback output\n")
        end

        session = Fatty::ShellSession.new(on_accept: callback)
        init_shell_session(session)

        session.field.buffer.replace("hello")
        commands = apply_action(session, :submit_and_scroll)
        expect(session.terminal)
          .to have_received(:apply_command)
                .with(have_attributes(action: :begin_command))
        expect(commands.map(&:action))
          .to eq([:append, :finish_command, :paging_to_scrolling])
        expect(commands[0].payload[:text]).to eq("callback output\n")
        expect(commands[0].target).to eq(session.output_session.id)
      end

      it "interrupts paging" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        allow(session.output_session).to receive(:pager_active?).and_return(true)

        commands = apply_action(session, :interrupt)

        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.action).to eq(:quit_paging)
      end

      it "interrupts by quitting when paging is inactive" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :interrupt)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:quit)
      end

      it "interrupt_if_empty quits when input is empty" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :interrupt_if_empty)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:quit)
      end

      it "interrupt_if_empty deletes forward when input is not empty" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        session.field.buffer.replace("abc")
        session.field.buffer.cursor = 1

        commands = apply_action(session, :interrupt_if_empty)

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("ac")
      end

      it "interrupt_if_empty quits paging when pager is active" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        allow(session.output_session).to receive(:pager_active?).and_return(true)

        commands = apply_action(session, :interrupt_if_empty)

        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.action).to eq(:quit_paging)
      end

      it "clears output" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :clear_output)

        expect(commands.first.target).to eq(session.output_session.id)
        expect(commands.first.action).to eq(:clear)
      end

      it "cycles theme" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :cycle_theme)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:cycle_theme)
      end

      it "chooses theme" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :choose_theme)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:choose_theme)
      end

      it "records prefix digits" do
        session = Fatty::ShellSession.new
        init_shell_session(session)

        commands = apply_action(session, :prefix_digit, 4)

        expect(commands).to eq([])
        expect(session.counter.digits).to eq("4")
      end

      it "cycles completion without changing real buffer text" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { %w[status stash] },
        )
        init_shell_session(session)

        session.field.buffer.replace("git st")

        commands = apply_action(session, :complete)

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("git st")
        expect(session.field.autosuggestion).to eq("git status")
      end

      it "cycles previous completion" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { %w[status stash] },
        )
        init_shell_session(session)

        session.field.buffer.replace("git st")

        apply_action(session, :complete)
        apply_action(session, :complete)

        commands = apply_action(session, :complete_previous)

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("git st")
        expect(session.field.autosuggestion).to eq("git status")
      end

      it "shows the next completion as a virtual suffix" do
        Dir.mktmpdir("fatty_shell_history") do |dir|
          history_path = File.join(dir, "history.jsonl")
          session = Fatty::ShellSession.new(
            completion_proc: ->(_buffer) { ["fold"] },
            history_path: history_path,
          )

          session.field.buffer.replace("fo")

          result = apply_action(session, :complete)

          expect(result).to eq([])
          expect(session.field.buffer.text).to eq("fo")
          expect(session.field.state[3]).to eq("ld")
        end
      end

      it "opens completion popup for multiple candidates" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { %w[clear cd] },
        )
        init_shell_session(session)

        session.field.buffer.replace("c")

        commands = apply_action(session, :completion_popup)

        popup = commands.first.payload.fetch(:session)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:push_modal)
        expect(popup).to be_a(Fatty::PopUpSession)
      end

      it "applies completion directly for a single candidate" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { %w[clear] },
        )
        init_shell_session(session)

        session.field.buffer.replace("cl")

        commands = apply_action(session, :completion_popup)

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("clear ")
      end

      it "does nothing for completion popup with no candidates" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { [] },
        )
        init_shell_session(session)

        session.field.buffer.replace("xyz")

        expect(apply_action(session, :completion_popup)).to eq([])
      end

      it "opens a popup instead of applying a single directory completion for a path without a trailing slash" do
        Dir.mktmpdir("fatty_popup") do |dir|
          FileUtils.mkdir_p(File.join(dir, "src"))
          File.write(File.join(dir, "src", "alpha.rb"), "x")
          File.write(File.join(dir, "src", "beta.rb"), "x")

          allow(Dir).to receive(:home).and_return(dir)

          session = Fatty::ShellSession.new
          init_shell_session(session)

          session.field.buffer.replace("ls -l ~/src")

          commands = apply_action(session, :completion_popup)

          popup = commands.first.payload.fetch(:session)

          expect(session.field.buffer.text).to eq("ls -l ~/src")
          expect(commands.first.target).to eq(:terminal)
          expect(commands.first.action).to eq(:push_modal)
          expect(popup).to be_a(Fatty::PopUpSession)
        end
      end

      it "seeds completion popup from the prefix before point" do
        session = Fatty::ShellSession.new(
          completion_proc: ->(_buffer) { %w[cd clear echo exit help history ls pwd theme] },
        )
        init_shell_session(session)

        session.field.buffer.text.replace("e four score and seven")
        session.field.buffer.cursor = 1

        commands = apply_action(session, :completion_popup)

        popup = commands.first.payload.fetch(:session)

        expect(commands.first.target).to eq(:terminal)
        expect(commands.first.action).to eq(:push_modal)
        expect(popup).to be_a(Fatty::PopUpSession)
        expect(popup.instance_variable_get(:@field).buffer.text).to eq("e")
      end

      it "opens command history search" do
        Dir.mktmpdir do |dir|
          history_path = File.join(dir, "history.jsonl")
          session = Fatty::ShellSession.new(history_path: history_path)
          init_shell_session(session)

          session.history.add("ls", kind: :command)
          session.history.add("needle", kind: :search_string)
          session.history.add("pwd", kind: :command)

          commands = apply_action(session, :history_search)

          popup = commands.first.payload.fetch(:session)

          expect(commands.first.target).to eq(:terminal)
          expect(commands.first.action).to eq(:push_modal)
          expect(popup).to be_a(Fatty::PopUpSession)
          expect(popup.send(:call_source, nil)).to eq(%w[ls pwd])
        end
      end
    end
  end
end
