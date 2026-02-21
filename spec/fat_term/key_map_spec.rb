# frozen_string_literal: true

require 'spec_helper'

# frozen_string_literal: true

module FatTerm
  RSpec.describe KeyMap do
    def ev(key, ctrl: false, meta: false, shift: false)
      KeyEvent.new(key:, ctrl:, meta:, shift:)
    end

    describe "#bind / #resolve" do
      it "returns nil when resolving nil event" do
        km = KeyMap.new
        expect(km.resolve(nil)).to be_nil
      end

      it "resolves an exact binding in default context (:input)" do
        km = KeyMap.new
        km.bind(key: :a, ctrl: true, action: :bol)

        # contexts: [] means "all contexts", so :input is searched.
        expect(km.resolve(ev(:a, ctrl: true))).to eq(:bol)
      end

      it "raises if contexts is an invalid type" do
        km = KeyMap.new
        expect { km.resolve(ev(:a), contexts: 123) }.to raise_error(ArgumentError)
      end

      it "supports user-defined contexts" do
        km = KeyMap.new
        km.bind(context: :search, key: :enter, action: :search_accept)

        expect(km.resolve(ev(:enter), contexts: :search)).to eq(:search_accept)
        expect(km.resolve(ev(:enter), contexts: :input)).to be_nil
      end

      it "uses the first matching context as precedence (contexts order)" do
        km = KeyMap.new
        km.bind(context: :input,  key: :enter, action: :submit)
        km.bind(context: :paging, key: :enter, action: :page_down)

        expect(km.resolve(ev(:enter), contexts: [:paging, :input])).to eq(:page_down)
        expect(km.resolve(ev(:enter), contexts: [:input, :paging])).to eq(:submit)
      end

      it "can resolve universal argument (C-u) in paging via :terminal context" do
        km = FatTerm::Keymaps.emacs

        # ShellSession uses contexts [:paging, :terminal] while paging.
        expect(km.resolve(ev(:u, ctrl: true), contexts: [:paging, :terminal])).to eq(:universal_argument)
      end

      it "raises if bind is missing an action keyword (explicit) OR action nil" do
        km = KeyMap.new
        expect { km.bind(key: :a, action: nil) }.to raise_error(ArgumentError)
      end

      it "resolves a bound action within a single context" do
        km = KeyMap.new
        km.bind(context: :input, key: :left, action: :cursor_left)

        expect(km.resolve(ev(:left), contexts: [:input])).to eq(:cursor_left)
      end

      it "does not resolve a binding from a different context" do
        km = KeyMap.new
        km.bind(context: :paging, key: :space, action: :page_down)

        expect(km.resolve(ev(:space), contexts: :input)).to be_nil
        expect(km.resolve(ev(:space), contexts: :paging)).to eq(:page_down)
      end

      it "does not fall back to unmodified binding when modified binding is absent" do
        km = KeyMap.new
        km.bind(key: :home, action: :bol)

        expect(km.resolve(ev(:home, ctrl: true), contexts: :input)).to be_nil
      end

      it "uses the first matching context as precedence (contexts array order)" do
        km = KeyMap.new
        km.bind(context: :input,  key: :enter, action: :submit)
        km.bind(context: :paging, key: :enter, action: :page_down)

        # paging should win because it is searched first
        expect(km.resolve(ev(:enter), contexts: [:paging, :input])).to eq(:page_down)
      end

      it "prefers the specific modified binding over the unmodified one" do
        km = KeyMap.new
        km.bind(key: :home, action: :bol)
        km.bind(key: :home, ctrl: true, action: :page_top)

        expect(km.resolve(ev(:home, ctrl: true), contexts: :input)).to eq(:page_top)
        expect(km.resolve(ev(:home), contexts: :input)).to eq(:bol)
      end

      it "treats contexts: nil as 'search all contexts' (registered order)" do
        km = KeyMap.new
        km.bind(context: :paging, key: :enter, action: :page_down)

        expect(km.resolve(ev(:enter), contexts: nil)).to eq(:page_down)
      end

      it "treats contexts: [] as 'search all contexts' (registered order)" do
        km = KeyMap.new
        km.bind(context: :paging, key: :enter, action: :page_down)

        expect(km.resolve(ev(:enter), contexts: [])).to eq(:page_down)
      end

      it "accepts contexts as Symbol, String, Array, nil, or []" do
        km = KeyMap.new
        km.bind(key: :a, ctrl: true, action: :bol)

        expect(km.resolve(ev(:a, ctrl: true), contexts: :input)).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), contexts: "input")).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), contexts: [:input])).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), contexts: nil)).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), contexts: [])).to eq(:bol)
      end

      it "returns nil if event is nil" do
        km = KeyMap.new
        expect(km.resolve(nil, contexts: [:input])).to be_nil
      end
    end

    describe "#contexts" do
      it "reports only contexts that have bindings (not merely looked up)" do
        km = KeyMap.new

        # this should NOT create empty contexts if resolve uses @bindings.fetch
        km.resolve(ev(:enter), contexts: [:input, :paging])

        expect(km.contexts).to eq([])

        km.bind(context: :input, key: :enter, action: :submit)
        expect(km.contexts).to include(:input)
      end
    end

    describe "#load_config" do
      it "loads bindings from Config.keybindings" do
        km = KeyMap.new
        cfg =
          [
            { "context" => "input", "key" => "enter", "action" => "submit" },
            { "context" => "paging", "key" => "enter", "action" => "page_down" },
            { "context" => "junk", "key" => "enter", "meta" => "true", "action" => "page_up" },
          ]
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_return(cfg)

        km.load_config

        expect(km.resolve(ev(:enter), contexts: [:input])).to eq(:submit)
        expect(km.resolve(ev(:enter), contexts: [:paging])).to eq(:page_down)
        expect(km.resolve(ev(:enter, meta: true), contexts: [:paging])).to be_nil
        expect(km.resolve(ev(:enter, meta: true), contexts: [:paging, :junk])).to eq(:page_up)
      end

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

        expect(km.resolve(ev(:a, ctrl: true), contexts: :input)).to eq(:bol)
        expect(km.resolve(ev(:space), contexts: :paging)).to eq(:page_down)
        expect(km.resolve(ev(:G, shift: true), contexts: :paging)).to eq(:page_bottom)
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
                                        { "key" => "b", "action" => nil }, # missing/invalid action
                                      ],
                                    )

        expect(km).to receive(:warn).at_least(:once)
        km.load_config
      end

      it "warns and continues on Psych::SyntaxError" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_raise(Psych::SyntaxError.new("", 0, 0, 0, "", ""))

        expect(km).to receive(:warn).at_least(:once).with(/syntax error/i)
        expect { km.load_config }.not_to raise_error
      end

      it "defaults missing context to :input" do
        km = KeyMap.new
        allow(FatTerm::Config).to receive(:keybindings)
                                    .and_return([{ "key" => "a", "ctrl" => true, "action" => "bol" }])

        km.load_config

        expect(km.resolve(ev(:a, ctrl: true), contexts: :input)).to eq(:bol)
        expect(km.resolve(ev(:a, ctrl: true), contexts: :paging)).to be_nil
      end
    end
  end
end
