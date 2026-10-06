# frozen_string_literal: true

require "spec_helper"

module Fatty
  module Curses
    RSpec.describe EventSource do
      def key_command(key, ctrl: false)
        Fatty::Command.session(
          :active,
          :key,
          event: Fatty::KeyEvent.new(key: key, ctrl: ctrl),
        )
      end

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

      describe "event handling" do
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

      describe "raw CSI keyboard input" do
        def source_for(raw)
          input = double('input window')
          allow(input).to receive(:timeout=)
          allow(input).to receive(:getch).and_return(*raw, nil)
          EventSource.new(context: instance_double(Context, input_win: input), poll_ms: 10)
        end

        before do
          allow(Fatty::Config).to receive(:config).and_return({ esc_delay: 10 })
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)
        end

        { 'D' => :left, 'C' => :right }.each do |suffix, key|
          [false, true].each do |integer_bytes|
            it "decodes Meta-#{key} with #{integer_bytes ? 'integer' : 'string'} bytes without inserting the sequence" do
              chars = "[1;3#{suffix}".chars
              chars = chars.map(&:ord) if integer_bytes
              source = source_for([27, *chars, 'x'])

              event = source.next_event.payload.fetch(:event)
              expect(event.key).to eq(key)
              expect(event.meta?).to be(true)
              expect(event.ctrl?).to be(false)
              expect(event.text).to be_nil
              expect(Fatty::Keymaps.emacs.resolve(event)).to eq(key == :left ? :move_word_left : :move_word_right)
              expect(source.next_event.payload.fetch(:event).text).to eq('x')
              expect(source.next_event).to be_nil
            end
          end
        end

        it 'decodes combined shift, control and meta modifiers' do
          event = source_for([27, *'[1;8D'.chars]).next_event.payload.fetch(:event)
          expect(event.key).to eq(:left)
          expect(event.shift?).to be(true)
          expect(event.ctrl?).to be(true)
          expect(event.meta?).to be(true)
        end

        { '1' => :home, '2' => :insert, '3' => :delete, '4' => :end,
          '5' => :page_up, '6' => :page_down, '7' => :home, '8' => :end }.each do |code, key|
          it "decodes navigation sequence #{code}~ and its modifier combinations" do
            (1..16).each do |modifier|
              sequence = modifier == 1 ? "[#{code}~" : "[#{code};#{modifier}~"
              source = source_for([27, *sequence.chars, 'x'])
              event = source.next_event.payload.fetch(:event)
              bits = modifier - 1
              expect(event.key).to eq(key)
              expect(event.shift?).to eq((bits & 1).positive?)
              expect(event.meta?).to eq((bits & 10).positive?)
              expect(event.ctrl?).to eq((bits & 4).positive?)
              expect(event.text).to be_nil
              expect(source.next_event.payload.fetch(:event).text).to eq('x')
            end
          end
        end

        { 'H' => :home, 'F' => :end }.each do |code, key|
          it "decodes Meta-#{key} in cursor-key form" do
            event = source_for([27, *"[1;3#{code}".chars]).next_event.payload.fetch(:event)
            expect(event.key).to eq(key)
            expect(event.meta?).to be(true)
            expect(event.text).to be_nil
          end
        end

        it 'uses a configured sequence through the input reader and preserves pasted bytes' do
          terminal = Fatty::Env.detect[:terminal]
          allow(Fatty::Config).to receive(:keydefs).and_return(
            { terminal => { sequences: { extra: { sequence: "\e[99~", key: "right", meta: true } } } },
          )
          source = source_for([27, *"[99~".chars, 27, *"[200~\e[99~\e[201~".chars, 'x'])
          event = source.next_event.payload.fetch(:event)
          expect(Fatty::Keymaps.emacs.resolve(event)).to eq(:move_word_right)
          paste = source.next_event
          expect(paste.action).to eq(:terminal_paste)
          expect(paste.payload[:text]).to eq("\e[99~")
          expect(source.next_event.payload.fetch(:event).text).to eq('x')
        end

        it 'preserves normal curses arrows' do
          allow(Fatty::Config).to receive(:keydefs).and_return(nil)
          event = source_for([::Curses::KEY_LEFT]).next_event.payload.fetch(:event)
          expect(event.key).to eq(:left)
          expect(event.meta?).to be(false)
        end

        it 'preserves bracketed paste as literal text, including escape sequences' do
          text = "hello\e[1;3D\n"
          source = source_for([27, *"[200~#{text}\e[201~".chars, 'x'])
          command = source.next_event
          expect(command.action).to eq(:terminal_paste)
          expect(command.payload[:text]).to eq(text)
          expect(source.next_event.payload.fetch(:event).text).to eq('x')
        end

        it 'reports an unsupported complete CSI sequence as one undefined key without text' do
          source = source_for([27, *'[99~'.chars, 'x'])
          event = source.next_event.payload.fetch(:event)
          expect(event.uncoded?).to be(true)
          expect(event.text).to be_nil
          expect(event.key).to include('[99~')
          expect(source.next_event.payload.fetch(:event).text).to eq('x')
        end

        it 'preserves a partial sequence and a following curses key' do
          source = source_for([27, '[', '1', ';', ::Curses::KEY_LEFT])
          expect(source.next_event.payload.fetch(:event).key).to eq(:escape)
          expect(3.times.map { source.next_event.payload.fetch(:event).text }.join).to eq('[1;')
          expect(source.next_event.payload.fetch(:event).key).to eq(:left)
        end
      end

      describe "#interrupt_pending?" do
        it "recognizes C-c" do
          allow(source).to receive(:read_event)
                             .with(timeout_ms: 0)
                             .and_return(key_command(:c, ctrl: true))

          expect(source.interrupt_pending?).to be true
        end

        it "recognizes C-g" do
          allow(source).to receive(:read_event)
                             .with(timeout_ms: 0)
                             .and_return(key_command(:g, ctrl: true))

          expect(source.interrupt_pending?).to be true
        end

        it "does not recognize Escape as an interrupt" do
          command = key_command(:escape)

          allow(source).to receive(:read_event)
                             .with(timeout_ms: 0)
                             .and_return(command)

          expect(source.interrupt_pending?).to be false
          expect(source.next_event).to be(command)
        end

        it "preserves a non-interrupt event for the normal event loop" do
          command = key_command(:x)

          allow(source).to receive(:read_event)
                             .with(timeout_ms: 0)
                             .and_return(command)

          expect(source.interrupt_pending?).to be false
          expect(source.next_event).to be(command)
        end

        it "preserves a resize command for the normal event loop" do
          command = Fatty::Command.terminal(:resize)

          allow(source).to receive(:read_event)
                             .with(timeout_ms: 0)
                             .and_return(command)

          expect(source.interrupt_pending?).to be false
          expect(source.next_event).to be(command)
        end
      end
    end
  end
end
