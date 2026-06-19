# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe SearchSession do
    def key(key, text: nil, ctrl: false, meta: false, shift: false)
      Fatty::KeyEvent.new(key: key, text: text, ctrl: ctrl, meta: meta, shift: shift)
    end

    def update(session, action, **payload)
      session.update(Fatty::Command.session(session.id, action, **payload))
    end

    describe "#initialize" do
      it "sets direction, regex mode, prompt, and optional prefix" do
        session = Fatty::SearchSession.new(
          direction: :forward,
          regex: true,
          prefix: "alpha",
        )

        expect(session.direction).to eq(:forward)
        expect(session.regex).to be(true)
        expect(session.field.prompt_text).to include("Regex")
        expect(session.field.buffer.text).to eq("alpha")
      end
    end

    describe "#update" do
      it "accepts the search and sends pager_search_set to the modal owner" do
        session = Fatty::SearchSession.new(direction: :forward, regex: true)
        session.field.buffer.replace("foo.*bar")

        commands = update(session, :key, event: key(:enter))

        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(session.id)
        expect(owner_command.action).to eq(:pager_search_set)
        expect(owner_command.payload).to include(pattern: "foo.*bar", direction: :forward, regex: true)
      end

      it "handles terminal_paste" do
        session = Fatty::SearchSession.new

        commands = update(session, :terminal_paste, text: "hello\nworld\n")

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("hello world ")
      end

      it "cancels the search" do
        session = Fatty::SearchSession.new

        commands = update(session, :key, event: key(:escape))

        expect(commands.map(&:action)).to eq([:pop_modal])
      end

      it "toggles regex mode" do
        session = Fatty::SearchSession.new(direction: :backward, regex: false)

        commands = update(session, :key, event: key(:r, meta: true))

        expect(commands).to eq([])
        expect(session.regex).to be(true)
        expect(session.field.prompt_text).to include("Regex")
        expect(session.field.prompt_text).to include("↑")
      end

      it "steps search forward" do
        session = Fatty::SearchSession.new

        commands = update(session, :key, event: key(:s, ctrl: true))

        expect(commands.length).to eq(1)
        expect(commands.first.action).to eq(:send_modal_owner)

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.target).to eq(session.id)
        expect(owner_command.action).to eq(:pager_search_step)
        expect(owner_command.payload[:direction]).to eq(:forward)
      end

      it "steps search backward" do
        session = Fatty::SearchSession.new

        commands = update(session, :key, event: key(:r, ctrl: true))

        owner_command = commands.first.payload.fetch(:command)

        expect(owner_command.action).to eq(:pager_search_step)
        expect(owner_command.payload[:direction]).to eq(:backward)
      end

      it "edits the input field for ordinary text keys" do
        session = Fatty::SearchSession.new

        commands = update(session, :key, event: key(:a, text: "a"))

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("a")
      end

      it "ignores unknown commands" do
        session = Fatty::SearchSession.new

        expect(update(session, :bogus)).to eq([])
      end
    end

    describe "#view" do
      it "renders the search field on the pager status row" do
        session = Fatty::SearchSession.new
        output_rect = instance_double("OutputRect", rows: 10)
        screen = instance_double(Fatty::Screen, output_rect: output_rect)
        renderer = instance_double(Fatty::Renderer::Truecolor)
        terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

        session.init(terminal: terminal)
        expect(renderer)
          .to receive(:show_cursor)
        expect(renderer)
          .to receive(:render_pager_field)
                .with(session.field, row: 9, role: :search_input)
        expect(renderer)
          .to receive(:restore_output_cursor)
                .with(session.field, row: 9)
        session.view
      end
    end
  end
end
