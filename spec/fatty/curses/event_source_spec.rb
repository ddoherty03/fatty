# frozen_string_literal: true

require "spec_helper"

module Fatty
  module Curses
    RSpec.describe EventSource do
      let(:window) { instance_double("window") }
      let(:context) { instance_double(Context, input_win: window) }
      let(:key_decoder) { instance_double(KeyDecoder) }
      let(:source) do
        EventSource.new(
          context: context,
          key_decoder: key_decoder,
          poll_ms: 10,
        )
      end

      it "returns a :cmd paste message when read_raw returns paste data" do
        allow(source).to receive(:read_raw).and_return([:paste, "hello\nworld\n"])
        event = source.next_event
        expect(event).to be_a(Command)
        expect(event.target).to eq(:active)
        expect(event.action).to eq(:terminal_paste)
        expect(event.payload[:text]).to eq("hello\nworld\n")
      end

      it "converts a resize key into a terminal resize command" do
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

      it "decodes ctrl scroll down as a modified mouse event" do
        mouse = instance_double(
          "Curses::MouseEvent",
          bstate: EventSource::SCROLL_DOWN_BSTATE | ::Curses::BUTTON_CTRL,
          x: 12,
          y: 5,
        )
        event = source.send(:decode_mouse, mouse)
        expect(event).to be_a(Fatty::MouseEvent)
        expect(event.button).to eq(:scroll_down)
        expect(event.ctrl).to be true
        expect(event.meta).to be false
        expect(event.shift).to be false
        expect(event.x).to eq(12)
        expect(event.y).to eq(5)
      end

      it "decodes ctrl scroll up as a modified mouse event" do
        mouse = instance_double(
          "Curses::MouseEvent",
          bstate: ::Curses::BUTTON4_PRESSED | ::Curses::BUTTON_CTRL,
          x: 12,
          y: 5,
        )
        event = source.send(:decode_mouse, mouse)
        expect(event).to be_a(Fatty::MouseEvent)
        expect(event.button).to eq(:scroll_up)
        expect(event.ctrl).to be true
        expect(event.meta).to be false
        expect(event.shift).to be false
      end

      it "decodes meta and shift modifiers on mouse events" do
        mouse = instance_double(
          "Curses::MouseEvent",
          bstate: ::Curses::BUTTON1_CLICKED | ::Curses::BUTTON_ALT | ::Curses::BUTTON_SHIFT,
          x: 2,
          y: 8,
        )
        event = source.send(:decode_mouse, mouse)
        expect(event.button).to eq(:left_clicked)
        expect(event.ctrl).to be false
        expect(event.meta).to be true
        expect(event.shift).to be true
      end

      it "decodes escape followed by a non-CSI key as a meta sequence" do
        window = instance_double("Window")
        allow(window).to receive(:getch).and_return(27, "f")
        allow(window).to receive(:timeout=)
        context = instance_double("Context", input_win: window)
        source = EventSource.new(context: context, key_decoder: key_decoder, poll_ms: 10)

        expect(source.send(:read_raw)).to eq([27, "f"])
      end

      it "returns bare escape when no following key arrives during escape lookahead" do
        window = instance_double("Window")
        allow(window).to receive(:getch).and_return(27, -1)
        allow(window).to receive(:timeout=)
        context = instance_double("Context", input_win: window)
        source = EventSource.new(context: context, key_decoder: key_decoder, poll_ms: 10)

        expect(source.send(:read_raw)).to eq(27)
      end

      it "strips mouse modifiers before resolving the wheel button" do
        bstate = ::Curses::BUTTON4_PRESSED |
                 ::Curses::BUTTON_CTRL |
                 ::Curses::BUTTON_ALT |
                 ::Curses::BUTTON_SHIFT

        expect(source.send(:mouse_button_from_bstate, bstate)).to eq(:scroll_up)
      end

      it "strips mouse modifiers before resolving the opposite wheel button" do
        bstate = EventSource::SCROLL_UP_BSTATE |
                 ::Curses::BUTTON_CTRL |
                 ::Curses::BUTTON_ALT |
                 ::Curses::BUTTON_SHIFT

        expect(source.send(:mouse_button_from_bstate, bstate)).to eq(:scroll_up)
      end
    end
  end
end
