# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Actions do
    def action_env(**kwargs)
      session = Struct.new(:id, :terminal).new(:action_spec, nil)
      Fatty::ActionEnvironment.new(session: session, **kwargs)
    end

    around do |example|
      with_action_registry { example.run }
    end

    before do
      Actions.reset!
    end

    describe ".register / .lookup / .registered?" do
      it "registers an action definition and allows lookup" do
        Actions.register(
          :bol,
          owner: String,
          on: :buffer,
          method_name: :bol,
          doc: "beginning of line",
        )

        defn = Actions.lookup(:bol)

        expect(defn).to include(
          owner: String,
          on: :buffer,
          method: :bol,
          doc: "beginning of line",
        )
        expect(Actions.registered?(:bol)).to be(true)
        expect(Actions.registered?("bol")).to be(true)
      end

      it "raises when registering the same action twice" do
        Actions.register(:bol, owner: String, on: :buffer)

        expect {
          Actions.register(:bol, owner: String, on: :buffer)
        }.to raise_error(ActionError, /already registered/i)
      end
    end

    describe ".names / .valid_names / .registered?" do
      it "reports registered names" do
        Actions.register(:zeta, owner: Object, on: :buffer)
        Actions.register(:alpha, owner: Object, on: :buffer)

        expect(Actions.names).to eq([:alpha, :zeta])
        expect(Actions.valid_names).to eq(["alpha", "zeta"])
        expect(Actions.registered?(:alpha)).to be(true)
        expect(Actions.registered?("alpha")).to be(true)
        expect(Actions.registered?(:missing)).to be(false)
      end
    end

    describe ".defs" do
      it "returns the registered action definitions" do
        Actions.register(:alpha, owner: Object, on: :buffer, doc: "A")

        expect(Actions.defs.keys).to eq([:alpha])
        expect(Actions.defs.fetch(:alpha))
          .to include(owner: Object, on: :buffer, doc: "A")
      end
    end

    describe ".catalog" do
      it "returns sorted action metadata" do
        Actions.register(:zeta, owner: Object, on: :session, method_name: :z, doc: "Z")
        Actions.register(:alpha, owner: Object, on: :buffer, method_name: :a, doc: "A")

        expect(Actions.catalog)
          .to eq(
                [
                  {
                    name: "alpha",
                    doc: "A",
                    on: "buffer",
                    method: "a",
                  },
                  {
                    name: "zeta",
                    doc: "Z",
                    on: "session",
                    method: "z",
                  },
                ],
              )
      end
    end

    describe ".catalog_by_target" do
      it "groups sorted action names by target" do
        Actions.register(:delete, owner: Object, on: :buffer)
        Actions.register(:complete, owner: Object, on: :session)
        Actions.register(:insert, owner: Object, on: :buffer)

        expect(Actions.catalog_by_target)
          .to eq(
                "buffer" => ["delete", "insert"],
                "session" => ["complete"],
              )
      end
    end

    describe ".call" do
      it "raises ActionError for unknown actions" do
        env = action_env(buffer: Object.new)

        expect {
          Actions.call(:nope, env)
        }.to raise_error(ActionError, /Unknown action/i)
      end

      it "raises ActionError when env target slot is nil" do
        Actions.register(:bol, owner: String, on: :buffer, method_name: :bol)
        env = action_env(buffer: nil)

        expect {
          Actions.call(:bol, env)
        }.to raise_error(ActionError, /env\.buffer is nil/i)
      end

      it "calls the registered method on the target" do
        target = Class.new do
          attr_reader :called

          def bol
            @called = true
          end
        end.new

        Actions.register(:bol, owner: target.class, on: :buffer)
        env = action_env(buffer: target)

        Actions.call(:bol, env)

        expect(target.called).to be(true)
      end

      it "forwards positional args and keyword args to the target method" do
        target = Class.new do
          attr_reader :args, :kwargs

          def insert(str, count: 1)
            @args = [str]
            @kwargs = { count: count }
          end
        end.new

        Actions.register(:insert, owner: target.class, on: :buffer)
        env = action_env(buffer: target)

        Actions.call(:insert, env, "x", count: 4)

        expect(target.args).to eq(["x"])
        expect(target.kwargs).to eq(count: 4)
      end

      it "consumes active counter when target method accepts count keyword" do
        target = Class.new do
          attr_reader :count

          def move_right(count: 1)
            @count = count
          end
        end.new
        counter = Counter.new
        counter.push_digit(7)
        env = action_env(buffer: target, counter: counter)

        Actions.register(:move_right, owner: target.class, on: :buffer)

        Actions.call(:move_right, env)

        expect(target.count).to eq(7)
        expect(counter).not_to be_active
      end

      it "does not consume active counter when count keyword is supplied" do
        target = Class.new do
          attr_reader :count

          def move_right(count: 1)
            @count = count
          end
        end.new
        counter = Counter.new
        counter.push_digit(7)
        env = action_env(buffer: target, counter: counter)

        Actions.register(:move_right, owner: target.class, on: :buffer)

        Actions.call(:move_right, env, count: 3)

        expect(target.count).to eq(3)
        expect(counter).to be_active
      end

      it "does not consume active counter when target method does not accept count" do
        target = Class.new do
          attr_reader :called

          def bol
            @called = true
          end
        end.new
        counter = Counter.new
        counter.push_digit(7)
        env = action_env(buffer: target, counter: counter)

        Actions.register(:bol, owner: target.class, on: :buffer)

        Actions.call(:bol, env)

        expect(target.called).to be(true)
        expect(counter).to be_active
      end

      it "passes count to methods accepting keyword rest" do
        target = Class.new do
          attr_reader :kwargs

          def flexible(**kwargs)
            @kwargs = kwargs
          end
        end.new
        counter = Counter.new
        counter.push_digit(5)
        env = action_env(buffer: target, counter: counter)

        Actions.register(:flexible, owner: target.class, on: :buffer)

        Actions.call(:flexible, env)

        expect(target.kwargs).to eq(count: 5)
        expect(counter).not_to be_active
      end
    end

    describe ".snapshot / .restore / .reset!" do
      it "snapshots and restores definitions" do
        Actions.register(:a, owner: Object, on: :buffer, doc: "A")
        snap = Actions.snapshot

        Actions.register(:b, owner: Object, on: :buffer, doc: "B")
        expect(Actions.lookup(:b)).not_to be_nil

        Actions.restore(snap)

        expect(Actions.lookup(:a)).not_to be_nil
        expect(Actions.lookup(:b)).to be_nil
      end

      it "reset! clears all definitions" do
        Actions.register(:a, owner: Object, on: :buffer)

        Actions.reset!

        expect(Actions.lookup(:a)).to be_nil
        expect(Actions.registered?(:a)).to be(false)
      end
    end
  end
end
