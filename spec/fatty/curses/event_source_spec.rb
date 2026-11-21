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

      let(:window) { instance_double(::Curses::Window) }
      let(:context) { instance_double(Context, input_win: window) }
      let(:key_decoder) { instance_double(KeyDecoder) }
      let(:source) do
        EventSource.new(
          context: context,
          key_decoder: key_decoder,
          poll_ms: 10,
        )
      end

      before do
        # These specs use fake windows; never consult an uninitialized native screen.
        allow(::Curses).to receive(:save_key_modifiers) if ::Curses.respond_to?(:save_key_modifiers)
        allow(::Curses).to receive(:get_key_modifiers).and_return(0) if ::Curses.respond_to?(:get_key_modifiers)
      end

      describe "PDCurses modifier flags" do
        let(:key_decoder) { KeyDecoder.new }
        let(:flags) { 6 } # Control + Alt
        let(:raw_code) { 0xec00 + 0xbd } # CTL_PGUP in the Unicode build

        before do
          backend = Module.new do
            def self.save_key_modifiers(_enabled); end

            def self.get_key_modifiers # rubocop:disable Naming/AccessorMethodName
              0
            end
          end
          stub_const("Curses", backend, transfer_nested_constants: true)
          stub_const("Curses::VERSION", "PDCurses test")
          stub_const("Curses::KEY_BACKSPACE", 0xec07)
          stub_const("Curses::PDC_KEY_MODIFIER_SHIFT", 1)
          stub_const("Curses::PDC_KEY_MODIFIER_CONTROL", 2)
          stub_const("Curses::PDC_KEY_MODIFIER_ALT", 4)
          allow(::Curses).to receive(:save_key_modifiers)
          allow(::Curses).to receive(:get_key_modifiers).and_return(flags)
          allow(WindowsKeyboard).to receive(:altgr_character?).and_return(false)
          allow(WindowsKeyboard).to receive(:altgr_character?).with("@").and_return(true)
          allow(Fatty::Config).to receive(:keydefs).and_return({})
          allow(window).to receive(:timeout=)
          allow(window).to receive(:getch).and_return(raw_code)
        end

        it "retains Control and Alt on Page Up without mutating the decoder map" do
          event = source.next_event.payload.fetch(:event)
          expect(event.to_s).to eq("C-M-page_up")
          expect(event.raw).to eq(raw_code)
          expect(key_decoder.decode(raw_code).to_s).to eq("C-page_up")
          expect(::Curses).to have_received(:save_key_modifiers).with(true)
        end

        context "with all three modifiers" do
          let(:flags) { 7 }

          it "retains Shift as well" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-M-S-page_up")
          end
        end

        context "with a function key" do
          let(:raw_code) { 0xec00 + 0x08 + 24 + 1 }

          it "retains the combined modifiers" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-M-f1")
          end
        end

        context "with printable AltGr text" do
          let(:raw_code) { "@" }

          it "preserves self-inserting text" do
            event = source.next_event.payload.fetch(:event)
            expect(event.text).to eq("@")
            expect(event.ctrl?).to be(false)
            expect(event.meta?).to be(false)
          end
        end

        [
          ["p", 0, "p", "p"],
          [16, 2, "C-p", nil],
          [0xec00 + 0xb0, 4, "M-p", nil],
          [16, 6, "C-M-p", nil],
          ["p", 4, "M-p", nil],
          ["p", 6, "C-M-p", nil],
          ["P", 5, "M-P", nil],
        ].each do |raw, modifiers, name, text|
          context "with #{name} reported as #{raw.inspect}" do
            let(:raw_code) { raw }
            let(:flags) { modifiers }

            it "retains the key and modifiers with the correct insertion behavior" do
              event = source.next_event.payload.fetch(:event)
              expect(event.to_s).to eq(name)
              expect(event.text).to eq(text)
            end
          end
        end

        context "with modified keypad Enter" do
          let(:raw_code) { 0xeccc }
          let(:flags) { 6 }

          it "retains both Control and Alt" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-M-keypad_enter")
          end
        end

        context "with a native Alt-keypad-7 code" do
          let(:raw_code) { 0xed0c }
          let(:flags) { 4 }

          it "keeps the keypad key distinct from Ctrl-G" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("M-keypad_7")
          end
        end

        context "with Ctrl-Backspace" do
          let(:raw_code) { 127 }
          let(:flags) { 2 }

          it "recovers Control on the DEL character used by Windows" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-backspace")
          end
        end

        context "with Ctrl-Alt-Backspace" do
          let(:raw_code) { 127 }
          let(:flags) { 6 }

          it "recovers both modifiers" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-M-backspace")
          end
        end

        context "with Alt-Backspace" do
          let(:raw_code) { 0xec00 + 0xf8 }
          let(:flags) { 4 }

          it "preserves the modifier already encoded in the keycode" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("M-backspace")
          end
        end

        context "with an unmodified BS character" do
          let(:raw_code) { 8 }
          let(:flags) { 0 }

          it "preserves the established Ctrl-H alias" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-h")
          end
        end

        context "with Ctrl-backtick" do
          let(:flags) { 2 }
          let(:raw_code) { "`" }

          it "recovers Control from the character's separate flags" do
            event = source.next_event.payload.fetch(:event)
            expect(event.to_s).to eq("C-`")
            expect(event.text).to be_nil
          end
        end

        context "with Ctrl-Alt-backtick on a layout where backtick needs no AltGr" do
          let(:flags) { 6 }
          let(:raw_code) { "`" }

          it "keeps both shortcut modifiers" do
            event = source.next_event.payload.fetch(:event)
            expect(event.to_s).to eq("C-M-`")
            expect(event.text).to be_nil
          end
        end

        context "with an integer Ctrl-backtick" do
          let(:flags) { 2 }
          let(:raw_code) { 96 }

          it "recovers Control for integer character input too" do
            expect(source.next_event.payload.fetch(:event).to_s).to eq("C-`")
          end
        end

        context "with a plain backtick" do
          let(:flags) { 0 }
          let(:raw_code) { "`" }

          it "keeps the character self-inserting" do
            event = source.next_event.payload.fetch(:event)
            expect(event.text).to eq("`")
            expect(event.ctrl?).to be(false)
          end
        end

        context "with a shifted printable character" do
          let(:flags) { 1 }
          let(:raw_code) { "~" }

          it "keeps Shift represented by the character" do
            event = source.next_event.payload.fetch(:event)
            expect(event.text).to eq("~")
            expect(event.shift?).to be(false)
          end
        end

        it "does not carry the prior chord into the next event" do
          source.next_event
          allow(window).to receive(:getch).and_return(::Curses::KEY_PPAGE)
          allow(::Curses).to receive(:get_key_modifiers).and_return(0)
          expect(source.next_event.payload.fetch(:event).to_s).to eq("page_up")
        end
      end

      describe "event handling" do
        # Exercise mouse decoding even when the installed backend has no mouse API.
        before(:each, :mouse_backend) do
          stub_const("Curses::MouseEvent", Struct.new(:bstate, :x, :y, keyword_init: true))
          stub_const("Curses::BUTTON1_CLICKED", 0x00000004)
          stub_const("Curses::BUTTON4_PRESSED", 0x00010000)
          stub_const("Curses::BUTTON_CTRL", 0x02000000)
          stub_const("Curses::BUTTON_ALT", 0x04000000)
          stub_const("Curses::BUTTON_SHIFT", 0x08000000)
          stub_const("Fatty::Curses::EventSource::SCROLL_UP_BSTATE", ::Curses::BUTTON4_PRESSED)
          stub_const(
            "Fatty::Curses::EventSource::MOUSE_MODIFIER_MASK",
            ::Curses::BUTTON_CTRL | ::Curses::BUTTON_ALT | ::Curses::BUTTON_SHIFT,
          )
          stub_const(
            "Fatty::Curses::EventSource::MOUSE_BSTATE_BUTTON_MAP",
            { ::Curses::BUTTON1_CLICKED => :left_clicked },
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

        it "decodes ctrl scroll down as a modified mouse event", :mouse_backend do
          mouse = instance_double(
            ::Curses::MouseEvent,
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

        it "decodes ctrl scroll up as a modified mouse event", :mouse_backend do
          mouse = instance_double(
            ::Curses::MouseEvent,
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

        it "decodes meta and shift modifiers on mouse events", :mouse_backend do
          mouse = instance_double(
            ::Curses::MouseEvent,
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
          window = instance_double(::Curses::Window)
          allow(window).to receive(:getch).and_return(27, "f")
          allow(window).to receive(:timeout=)
          context = instance_double(Context, input_win: window)
          source = EventSource.new(context: context, key_decoder: key_decoder, poll_ms: 10)

          expect(source.send(:read_raw)).to eq([27, "f"])
        end

        it "returns bare escape when no following key arrives during escape lookahead" do
          window = instance_double(::Curses::Window)
          allow(window).to receive(:getch).and_return(27, -1)
          allow(window).to receive(:timeout=)
          context = instance_double(Context, input_win: window)
          source = EventSource.new(context: context, key_decoder: key_decoder, poll_ms: 10)

          expect(source.send(:read_raw)).to eq(27)
        end

        it "strips mouse modifiers before resolving the wheel button", :mouse_backend do
          bstate = ::Curses::BUTTON4_PRESSED |
                   ::Curses::BUTTON_CTRL |
                   ::Curses::BUTTON_ALT |
                   ::Curses::BUTTON_SHIFT

          expect(source.send(:mouse_button_from_bstate, bstate)).to eq(:scroll_up)
        end

        it "strips mouse modifiers before resolving the opposite wheel button", :mouse_backend do
          bstate = EventSource::SCROLL_DOWN_BSTATE |
                   ::Curses::BUTTON_CTRL |
                   ::Curses::BUTTON_ALT |
                   ::Curses::BUTTON_SHIFT

          expect(source.send(:mouse_button_from_bstate, bstate)).to eq(:scroll_down)
        end
      end

      describe "raw CSI keyboard input" do
        def source_for(raw)
          input = instance_double(::Curses::Window)
          allow(input).to receive(:timeout=)
          allow(input).to receive(:getch).and_return(*raw, nil)
          EventSource.new(context: instance_double(Context, input_win: input), poll_ms: 10)
        end

        before do
          allow(Fatty::Config).to receive_messages(config: { esc_delay: 10 }, keydefs: nil)
        end

        byte_formats = [false, true]
        { 'D' => :left, 'C' => :right }.each do |suffix, key|
          byte_formats.each do |integer_bytes|
            it "decodes Meta-#{key} with #{integer_bytes ? 'integer' : 'string'} bytes without inserting text" do
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

        {
          '1' => :home,
          '2' => :insert,
          '3' => :delete,
          '4' => :end,
          '5' => :page_up,
          '6' => :page_down,
          '7' => :home,
          '8' => :end
        }.each do |code, key|
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
          expect(Array.new(3) { source.next_event.payload.fetch(:event).text }.join).to eq('[1;')
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
