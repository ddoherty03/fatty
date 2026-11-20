# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Backspace bindings" do
  before { allow(Fatty::Config).to receive(:keydefs).and_return(nil) }

  [8, "\b", 127, Curses::KEY_BACKSPACE].each do |raw|
    it "deletes backward for #{raw.inspect} in text fields" do
      event = Fatty::Curses::KeyDecoder.new.decode(raw)
      expect(Fatty::Keymaps.emacs.resolve(event, contexts: [:input, :text, :terminal]))
        .to eq(:delete_char_backward)
    end
  end

  it "kills the previous word for Meta-Control-h" do
    event = Fatty::KeyEvent.new(key: :h, ctrl: true, meta: true)
    expect(Fatty::Keymaps.emacs.resolve(event, contexts: :text)).to eq(:kill_word_backward)
  end

  [0xec00, 0x100].each do |offset|
    it "recognizes PDCurses Alt-Backspace with offset #{offset}" do
      stub_const("Curses::VERSION", "PDCursesMod 4.5.4")
      stub_const("Curses::KEY_BACKSPACE", offset + 7)
      event = Fatty::Curses::KeyDecoder.new.decode(offset + 0xf8)
      expect(event.key).to eq(:backspace)
      expect(event.meta?).to be(true)
      expect(Fatty::Keymaps.emacs.resolve(event, contexts: :text)).to eq(:kill_word_backward)
    end
  end

  it "does not interpret PDCurses codes on ncurses" do
    stub_const("Curses::VERSION", "ncurses 6.5")
    expect(Fatty::Curses::KeyDecoder.new.decode(60664).key).to eq(60664)
  end

  it "allows user definitions to override PDCurses Alt-Backspace" do
    stub_const("Curses::VERSION", "PDCursesMod 4.5.4")
    stub_const("Curses::KEY_BACKSPACE", 0xec07)
    allow(Fatty::Config).to receive(:keydefs).and_return({ xterm: { 60664 => { key: :custom_backspace } } })
    expect(Fatty::Curses::KeyDecoder.new(env: { terminal: :xterm }).decode(60664).key).to eq(:custom_backspace)
  end

  it "keeps forward Delete and the pager's Control-h binding" do
    decoder = Fatty::Curses::KeyDecoder.new
    map = Fatty::Keymaps.emacs
    expect(map.resolve(decoder.decode(Curses::KEY_DC), contexts: :text)).to eq(:delete_char_forward)
    expect(map.resolve(decoder.decode(8), contexts: [:paging, :terminal])).to eq(:page_up)
  end
end
