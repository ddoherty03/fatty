# frozen_string_literal: true

require "spec_helper"

module Fatty
  module Curses
    RSpec.describe EventSource do
      let(:window) { instance_double("window") }
      let(:context) { instance_double(Context, input_win: window) }
      let(:key_decoder) { instance_double(KeyDecoder) }

      it "returns a :cmd paste message when read_raw returns paste data" do
        source = EventSource.new(
          context: context,
          key_decoder: key_decoder,
          poll_ms: 10,
        )
        allow(source).to receive(:read_raw).and_return([:paste, "hello\nworld\n"])
        event = source.next_event
        expect(event).to be_a(Command)
        expect(event.target).to eq(:active)
        expect(event.action).to eq(:terminal_paste)
        expect(event.payload[:text]).to eq("hello\nworld\n")
      end

      it "converts a resize key into a terminal resize command" do
        source = EventSource.new(
          context: context,
          key_decoder: key_decoder,
          poll_ms: 10,
        )
        allow(source).to receive(:read_raw).and_return(::Curses::KEY_RESIZE)
        allow(key_decoder)
          .to receive(:decode)
                .with(::Curses::KEY_RESIZE)
                .and_return(Fatty::KeyEvent.new(key: :resize))
        command = source.next_event
        expect(command.target).to eq(:terminal)
        expect(command.action).to eq(:resize)
      end

      it "returns a mouse event command when read_raw returns a mouse event" do
        mouse = Fatty::MouseEvent.new(
          button: :left,
          x: 3,
          y: 7,
          ctrl: false,
          meta: false,
          shift: false,
        )
        source = EventSource.new(context: Context.new)
        allow(source).to receive(:read_raw).and_return(mouse)

        command = source.next_event
        expect(command).to be_a(Fatty::Command)
        expect(command.target).to eq(:active)
        expect(command.action).to eq(:key)
        ev = command.payload.fetch(:event)
        expect(ev).to eq(mouse)
        expect(ev.x).to eq(3)
        expect(ev.y).to eq(7)
        expect(ev.key).to eq(:mouse)
        expect(ev.button).to eq(:left)
        expect(ev.ctrl).to be false
        expect(ev.meta).to be false
        expect(ev.shift).to be false
        expect(ev.printable?).to be false
        expect(ev.mouse?).to be true
      end
    end
  end
end
