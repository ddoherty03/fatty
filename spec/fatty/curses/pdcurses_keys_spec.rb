# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Curses::PDCursesKeys do
  # Independent representative values from the PDCurses headers, covering
  # each group and both key-offset conventions.
  samples = {
    0xea => [:up, :meta],
    0xe8 => [:page_down, :meta],
    0xed => [:left, :meta],
    0xeb => [:down, :meta],
    0xe6 => [:home, :meta],
    0xe9 => [:end, :meta],
    0xdf => [:insert, :meta],
    0xde => [:delete, :meta],
    0xe0 => [:up, :ctrl],
    0xbd => [:page_up, :ctrl],
    0x10f => [:delete, :ctrl],
    0x123 => [:up, :shift],
    0x124 => [:down, :shift],
    0xa6 => [:f, :meta],
    0x9a => [:'3', :meta],
    0xf7 => [:/, :meta],
    0x110 => [:'\\', :meta],
    0xcc => [:keypad_enter, :ctrl],
    0x10e => [:keypad_9, :meta],
    0x113 => [:keypad_divide, :shift],
    0x15 => [:f1, :shift],
    0x20 => [:f12, :shift],
    0x21 => [:f1, :ctrl],
    0x2c => [:f12, :ctrl],
    0x2d => [:f1, :meta],
    0x38 => [:f12, :meta],
  }
  [0xec00, 0x100].each do |offset|
    samples.each do |relative, (key, modifier)|
      it "decodes #{modifier}-#{key} at offset #{offset}" do
        allow(Fatty::Config).to receive(:keydefs).and_return(nil)
        stub_const("Curses::VERSION", "PDCursesMod 4.5.4")
        stub_const("Curses::KEY_BACKSPACE", offset + 7)
        event = Fatty::Curses::KeyDecoder.new.decode(offset + relative)
        expect(event.key).to eq(key)
        expect(event.raw).to eq(offset + relative)
        [:ctrl, :meta, :shift].each { |flag| expect(event.public_send(:"#{flag}?")).to eq(flag == modifier) }
      end
    end
  end

  it "leaves unknown codes undefined and leaves actions to the keymap" do
    allow(Fatty::Config).to receive(:keydefs).and_return(nil)
    stub_const("Curses::VERSION", "PDCursesMod 4.5.4")
    stub_const("Curses::KEY_BACKSPACE", 0xec07)
    decoder = Fatty::Curses::KeyDecoder.new
    expect(decoder.decode(0xee00).uncoded?).to be(true)
    event = decoder.decode(0xecea)
    map = Fatty::KeyMap.new
    expect(map.resolve(event, contexts: :text)).to be_nil
    map.bind(key: :up, meta: true, action: :history_prev)
    expect(map.resolve(event, contexts: :text)).to eq(:history_prev)
  end
end
