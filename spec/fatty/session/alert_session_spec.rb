# frozen_string_literal: true

require "ostruct"
require "spec_helper"

module Fatty
  RSpec.describe AlertSession do
    def init_alert_session(session, row: 23, cols: 80, theme_version: 0)
      alert_rect = OpenStruct.new(row: row, cols: cols)
      screen = instance_double(Fatty::Screen, alert_rect: alert_rect)
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
      it "starts without a current alert" do
        session = Fatty::AlertSession.new

        expect(session.current).to be_nil
      end
    end

    describe "#update" do
      it "shows an alert from payload values" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        commands = update(
          session,
          :show,
          role: :warn,
          text: "Careful",
          details: { key: "C-x" },
          sticky: true,
        )

        expect(commands).to eq([])
        expect(session.current).to be_a(Fatty::Alert)
        expect(session.current.role).to eq(:warn)
        expect(session.current.text).to eq("Careful")
        expect(session.current.details).to eq(key: "C-x")
        expect(session.current).to be_sticky
      end

      it "shows an alert object directly" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        alert = Fatty::Alert.error("Boom")

        commands = update(session, :show, alert: alert)

        expect(commands).to eq([])
        expect(session.current).to be(alert)
      end

      it "defaults payload alerts to info role" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        update(session, :show, text: "Hello")

        expect(session.current.role).to eq(:info)
        expect(session.current.text).to eq("Hello")
      end

      it "shows an empty info alert from nil alert payloads" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        commands = update(session, :show, alert: nil)

        expect(commands).to eq([])
        expect(session.current).to be_a(Fatty::Alert)
        expect(session.current.text).to eq("")
        expect(session.current.role).to eq(:info)
        expect(session.current.details).to be_nil
        expect(session.current).not_to be_sticky
      end

      it "clears non-sticky alerts" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        update(session, :show, text: "Bye")

        commands = update(session, :clear)

        expect(commands).to eq([])
        expect(session.current).to be_nil
      end

      it "does not clear sticky alerts" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        update(session, :show, text: "Keep", sticky: true)

        commands = update(session, :clear)

        expect(commands).to eq([])
        expect(session.current.text).to eq("Keep")
        expect(session.current).to be_sticky
      end

      it "ignores unknown commands" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        expect(update(session, :bogus)).to eq([])
        expect(session.current).to be_nil
      end
    end

    describe "#view" do
      it "renders itself through the renderer" do
        session = Fatty::AlertSession.new
        init_alert_session(session)

        expect(session.renderer).to receive(:render_alert).with(session)

        session.view
      end
    end

    describe "#state" do
      it "returns renderer-facing alert state" do
        session = Fatty::AlertSession.new
        init_alert_session(session, row: 22, cols: 72, theme_version: 5)

        update(
          session,
          :show,
          text: "Careful",
          role: :warn,
          details: { key: "C-x" },
        )

        expect(session.state).to eq(
          [
            "Careful",
            :warn,
            { key: "C-x" },
            22,
            72,
            5,
          ],
        )
      end

      it "returns nil alert fields when hidden" do
        session = Fatty::AlertSession.new
        init_alert_session(session, row: 22, cols: 72, theme_version: 5)

        expect(session.state).to eq(
          [
            nil,
            nil,
            nil,
            22,
            72,
            5,
          ],
        )
      end
    end
  end
end
