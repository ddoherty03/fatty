# frozen_string_literal: true

require "ostruct"

module Fatty
  RSpec.describe StatusSession do
    def init_status_session(session, rows: 1, cols: 80, theme_version: 0)
      status_rect = OpenStruct.new(row: 20, rows: rows, cols: cols)
      screen = instance_double(Fatty::Screen, cols: cols, status_rect: status_rect)
      renderer = instance_double(
        Fatty::Renderer,
        screen: screen,
        theme_version: theme_version,
      )
      terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

      session.init(terminal: terminal)
      session
    end

    describe "#initialize" do
      it "starts hidden with info role" do
        session = Fatty::StatusSession.new

        expect(session.text).to be_nil
        expect(session.role).to eq(:info)
      end
    end

    describe "#update" do
      it "shows status text and refreshes layout when row count changes" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        commands = update(session, :show, text: "Hello", role: :good)

        expect(session.text).to eq("Hello")
        expect(session.role).to eq(:good)
        expect(commands.map(&:action)).to eq([:set_status_rows, :refresh_layout])
        expect(commands.first.payload[:rows]).to eq(1)
      end

      it "shows status text with default info role" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        update(session, :show, text: "Hello")

        expect(session.role).to eq(:info)
      end

      it "does not refresh layout when row count is unchanged" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        update(session, :show, text: "Hello")
        commands = update(session, :show, text: "World")

        expect(commands).to eq([])
      end

      it "clears visible status and refreshes layout" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        update(session, :show, text: "Hello")
        commands = update(session, :clear)

        expect(session.text).to be_nil
        expect(session.role).to eq(:info)
        expect(commands.map(&:action)).to eq([:set_status_rows, :refresh_layout])
        expect(commands.first.payload[:rows]).to eq(0)
      end

      it "does nothing when clearing hidden status" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        expect(update(session, :clear)).to eq([])
      end

      it "ignores unknown commands" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        expect(update(session, :bogus)).to eq([])
      end
    end

    describe "#view" do
      it "does not render when hidden" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        expect(session.renderer).not_to receive(:render_status)

        session.view
      end

      it "renders itself when visible" do
        session = Fatty::StatusSession.new
        init_status_session(session)

        update(session, :show, text: "Hello")

        expect(session.renderer).to receive(:render_status).with(session)

        session.view
      end
    end

    describe "#state" do
      it "returns renderer-facing status state" do
        session = Fatty::StatusSession.new
        init_status_session(session, rows: 2, cols: 70, theme_version: 9)

        update(session, :show, text: "Hello", role: :warn)

        expect(session.state).to eq(
          [
            "Hello",
            :warn,
            20,
            2,
            70,
            9,
          ],
        )
      end
    end
  end
end
