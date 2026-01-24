# frozen_string_literal: true

require 'spec_helper'

module FatTerm
  RSpec.describe KeyMap do
    # Helper: make a KeyEvent without depending on decoding/curses.
    def ev(key, ctrl: false, meta: false, shift: false)
      KeyEvent.new(key: key, ctrl: ctrl, meta: meta, shift: shift)
    end

    describe "#bind / #resolve" do
      it "returns nil when resolving nil event" do
        km = KeyMap.new
        expect(km.resolve(nil)).to be_nil
      end

      it "resolves an exact binding in default context (:input)" do
        km = KeyMap.new
        km.bind(key: :a, ctrl: true, action: :bol)

        expect(km.resolve(ev(:a, ctrl: true))).to eq(:bol)
      end

      it "does not resolve a binding from a different context" do
        km = KeyMap.new
        km.bind(context: :paging, key: :space, action: :page_down)

        expect(km.resolve(ev(:space), context: :input)).to be_nil
        expect(km.resolve(ev(:space), context: :paging)).to eq(:page_down)
      end

      it "falls back to unmodified binding when modified binding is absent" do
        km = KeyMap.new
        km.bind(key: :home, action: :bol)

        # No explicit ctrl-home binding, should fall back to :home
        expect(km.resolve(ev(:home, ctrl: true))).to eq(:bol)
      end

      it "prefers the specific modified binding over the unmodified one" do
        km = KeyMap.new
        km.bind(key: :home, action: :bol)
        km.bind(key: :home, ctrl: true, action: :page_top)

        expect(km.resolve(ev(:home, ctrl: true))).to eq(:page_top)
        expect(km.resolve(ev(:home))).to eq(:bol)
      end

      it "raises if context is not a symbol" do
        km = KeyMap.new
        expect { km.resolve(ev(:a), context: "input") }.to raise_error(ArgumentError)
      end

      it "raises if bind is missing an action keyword (explicit) OR action nil" do
        km = KeyMap.new

        # If your bind requires action: keyword, this should raise ArgumentError
        # If it allows action: nil, change expectation accordingly.
        expect { km.bind(key: :a, action: nil) }.to raise_error(ArgumentError)
      end
    end

    describe "#load_config" do
      it "is a no-op when Config.keybindings returns nil" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings).and_return(nil)

        expect { km.load_config }.not_to raise_error
        expect(km.resolve(ev(:a, ctrl: true))).to be_nil
      end

      it "is a no-op when Config.keybindings returns a non-array" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings).and_return({})

        expect { km.load_config }.not_to raise_error
      end

      it "binds entries from config (including context/modifiers)" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_return(
                                      [
                                        { "key" => "a", "ctrl" => true, "action" => "bol" },
                                        { "key" => "space", "context" => "paging", "action" => "page_down" },
                                        { "key" => "G", "context" => "paging", "shift" => true, "action" => "page_bottom" },
                                      ],
                                    )

        km.load_config

        expect(km.resolve(ev(:a, ctrl: true), context: :input)).to eq(:bol)
        expect(km.resolve(ev(:space), context: :paging)).to eq(:page_down)
        expect(km.resolve(ev(:G, shift: true), context: :paging)).to eq(:page_bottom)
      end

      it "skips invalid (non-hash) entries with a warning" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings).and_return([123, "nope"])
        expect(km).to receive(:warn).at_least(:once)

        km.load_config
      end

      it "skips entries missing key or action with a warning" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_return(
                                      [
                                        { "key" => "a" },                 # missing action
                                        { "action" => "bol" },            # missing key
                                        { "key" => "b", "action" => nil } # missing/invalid action
                                      ],
                                    )
        expect(km).to receive(:warn).at_least(:once)
        km.load_config
      end

      it "warns and continues on Psych::SyntaxError" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings).and_raise(Psych::SyntaxError.new("", 0, 0, 0, "", ""))

        expect(km).to receive(:warn).at_least(:once).with(/syntax error/i)
        expect { km.load_config }.not_to raise_error
      end

      it "defaults missing context to :input" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_return([{ "key" => "a", "ctrl" => true, "action" => "bol" }])

        km.load_config

        expect(km.resolve(ev(:a, ctrl: true), context: :input)).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), context: :paging)).to be_nil
      end
    end
  end
end
