# frozen_string_literal: true

module Fatty
  RSpec.describe Actions do
    let(:snapshot) { Actions.snapshot }

    around do |example|
      with_action_registry { example.run }
    end

    before do
      Fatty::Actions.reset!
    end

    describe ".register / .lookup / .registered?" do
      it "registers an Actions definition and allows lookup" do
        Actions.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: "beginning of line")

        defn = Actions.lookup(:bol)
        expect(defn).to include(owner: String, on: :buffer, method: :bol, doc: "beginning of line")
        expect(Actions.registered?(:bol)).to be(true)
      end

      it "raises when registering the same Actions twice" do
        Actions.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)

        expect {
          Actions.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)
        }.to raise_error(ActionError, /already registered/i)
      end
    end

    describe ".call" do
      it "raises ActionsError for unknown Actions" do
        ctx = ActionEnvironment.new(buffer: Object.new)

        expect {
          Actions.call(:nope, ctx)
        }.to raise_error(ActionError, /Unknown action/i)
      end

      it "raises ActionsError when ctx target slot is nil" do
        Actions.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)

        env = ActionEnvironment.new(buffer: nil)

        expect {
          Actions.call(:bol, env)
        }.to raise_error(ActionError, /env\.buffer is nil/i)
      end

      it "calls the registered method on the ctx target" do
        target = Class.new do
          attr_reader :called

          def bol
            @called = true
          end
        end.new

        Actions.register(:bol, owner: target.class, on: :buffer, method_name: :bol, doc: nil)
        ctx = ActionEnvironment.new(buffer: target)
        Actions.call(:bol, ctx)
        expect(target.called).to be(true)
      end

      it "forwards positional args and keyword args to the target method" do
        target = Class.new do
          attr_reader :args, :kwargs

          def delete_char_backward(count: 1, unit: :char)
            @args = []
            @kwargs = { count: count, unit: unit }
          end

          def insert(str, count: 1)
            @args = [str]
            @kwargs = { count: count }
          end
        end.new

        Actions.register(:delete_char_backward, owner: target.class, on: :buffer, method_name: :delete_char_backward, doc: nil)
        Actions.register(:insert, owner: target.class, on: :buffer, method_name: :insert, doc: nil)

        ctx = ActionEnvironment.new(buffer: target)

        Actions.call(:delete_char_backward, ctx, count: 3, unit: :word)
        expect(target.args).to eq([])
        expect(target.kwargs).to eq(count: 3, unit: :word)

        Actions.call(:insert, ctx, "x", count: 4)
        expect(target.args).to eq(["x"])
        expect(target.kwargs).to eq(count: 4)
      end
    end

    describe ".snapshot / .restore / .reset!" do
      it "snapshots and restores definitions" do
        Actions.register(:a, owner: Object, on: :buffer, method_name: :a, doc: "A")
        snap = Actions.snapshot

        Actions.register(:b, owner: Object, on: :buffer, method_name: :b, doc: "B")
        expect(Actions.lookup(:b)).not_to be_nil

        Actions.restore(snap)
        expect(Actions.lookup(:a)).not_to be_nil
        expect(Actions.lookup(:b)).to be_nil
      end

      it "reset! clears all definitions" do
        Actions.register(:a, owner: Object, on: :buffer, method_name: :a, doc: nil)
        Actions.reset!
        expect(Actions.lookup(:a)).to be_nil
        expect(Actions.registered?(:a)).to be(false)
      end

      it "does not leak action registrations between examples" do
        before = Fatty::Actions.defs.keys.sort

        with_action_registry do
          Fatty::Actions.register(:temp_action, owner: self, on: :session)
        end

        after = Fatty::Actions.defs.keys.sort
        expect(after).to eq(before)
      end
    end
  end
end
