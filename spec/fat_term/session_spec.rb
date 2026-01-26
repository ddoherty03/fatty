# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe Session do
    describe "#update" do
      it "is abstract by default" do
        s = Session.new
        expect { s.update(:event, terminal: :terminal) }.to raise_error(NotImplementedError)
      end
    end

    describe "commands" do
      it "starts with an empty command queue" do
        s = Session.new
        expect(s.commands).to eq([])
      end

      it "emit appends commands" do
        s = Session.new
        s.emit([:beep])
        s.emit([:open, "file.txt"])

        expect(s.commands).to eq([[:beep], [:open, "file.txt"]])
      end

      it "drain_commands returns commands and clears the queue" do
        s = Session.new
        s.emit([:beep])
        s.emit([:open, "file.txt"])

        drained = s.drain_commands
        expect(drained).to eq([[:beep], [:open, "file.txt"]])
        expect(s.commands).to eq([])
      end

      it "drain_commands returns a fresh array (caller can't mutate internal queue)" do
        s = Session.new
        s.emit([:beep])

        drained = s.drain_commands
        drained << [:oops]

        expect(s.commands).to eq([])
      end
    end

    describe "focus" do
      it "is active by default" do
        s = Session.new
        expect(s).to be_active
      end

      it "blur! marks inactive; focus! marks active" do
        s = Session.new

        s.blur!
        expect(s).not_to be_active

        s.focus!
        expect(s).to be_active
      end

      it "focus!/blur! return self for chaining" do
        s = Session.new
        expect(s.blur!).to be(s)
        expect(s.focus!).to be(s)
      end
    end

    describe "views" do
      it "accepts initial views" do
        v1 = instance_double(View)
        v2 = instance_double(View)

        s = Session.new(views: [v1, v2])
        expect(s.views).to eq([v1, v2])
      end

      it "defaults to an empty views list" do
        s = Session.new
        expect(s.views).to eq([])
      end

      it "add_view appends a view and returns self" do
        v = instance_double(View)
        s = Session.new

        expect(s.add_view(v)).to be(s)
        expect(s.views).to eq([v])
      end
    end

    describe "keymap" do
      it "stores the keymap provided at initialization" do
        km = instance_double(KeyMap)
        s = Session.new(keymap: km)
        expect(s.keymap).to be(km)
      end

      it "allows the runtime to replace the keymap" do
        km1 = instance_double(KeyMap)
        km2 = instance_double(KeyMap)

        s = Session.new(keymap: km1)
        s.keymap = km2

        expect(s.keymap).to be(km2)
      end
    end

    describe "context" do
      it "defaults to :default" do
        s = Session.new
        expect(s.context).to eq(:default)
      end

      it "coerces context to a symbol when provided" do
        s = Session.new(context: "input")
        expect(s.context).to eq(:input)
      end

      it "allows changing context" do
        s = Session.new(context: :input)
        s.context = :completion
        expect(s.context).to eq(:completion)
      end
    end
  end
end
