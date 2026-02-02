# frozen_string_literal: true

RSpec.describe FatTerm::Actions do
  let(:snapshot) { described_class.snapshot }

  before do
    described_class.reset!
  end

  after do
    described_class.restore(snapshot)
  end

  describe ".register / .lookup / .registered?" do
    it "registers an action definition and allows lookup" do
      described_class.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: "beginning of line")

      defn = described_class.lookup(:bol)
      expect(defn).to include(owner: String, on: :buffer, method: :bol, doc: "beginning of line")
      expect(described_class.registered?(:bol)).to be(true)
    end

    it "raises when registering the same action twice" do
      described_class.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)

      expect {
        described_class.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)
      }.to raise_error(FatTerm::ActionError, /already registered/i)
    end
  end

  describe ".call" do
    it "raises ActionError for unknown action" do
      ctx = FatTerm::ActionContext.new(buffer: Object.new)

      expect {
        described_class.call(:nope, ctx)
      }.to raise_error(FatTerm::ActionError, /Unknown action/i)
    end

    it "raises ActionError when ctx target slot is nil" do
      described_class.register(:bol, owner: String, on: :buffer, method_name: :bol, doc: nil)

      ctx = FatTerm::ActionContext.new(buffer: nil)

      expect {
        described_class.call(:bol, ctx)
      }.to raise_error(FatTerm::ActionError, /ctx\.buffer is nil/i)
    end

    it "calls the registered method on the ctx target" do
      target = Class.new do
        attr_reader :called

        def bol
          @called = true
        end
      end.new

      described_class.register(:bol, owner: target.class, on: :buffer, method_name: :bol, doc: nil)

      ctx = FatTerm::ActionContext.new(buffer: target)

      described_class.call(:bol, ctx)
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

      described_class.register(:delete_char_backward, owner: target.class, on: :buffer, method_name: :delete_char_backward, doc: nil)
      described_class.register(:insert, owner: target.class, on: :buffer, method_name: :insert, doc: nil)

      ctx = FatTerm::ActionContext.new(buffer: target)

      described_class.call(:delete_char_backward, ctx, count: 3, unit: :word)
      expect(target.args).to eq([])
      expect(target.kwargs).to eq(count: 3, unit: :word)

      described_class.call(:insert, ctx, "x", count: 4)
      expect(target.args).to eq(["x"])
      expect(target.kwargs).to eq(count: 4)
    end
  end

  describe ".snapshot / .restore / .reset!" do
    it "snapshots and restores definitions" do
      described_class.register(:a, owner: Object, on: :buffer, method_name: :a, doc: "A")
      snap = described_class.snapshot

      described_class.register(:b, owner: Object, on: :buffer, method_name: :b, doc: "B")
      expect(described_class.lookup(:b)).not_to be_nil

      described_class.restore(snap)
      expect(described_class.lookup(:a)).not_to be_nil
      expect(described_class.lookup(:b)).to be_nil
    end

    it "reset! clears all definitions" do
      described_class.register(:a, owner: Object, on: :buffer, method_name: :a, doc: nil)
      described_class.reset!
      expect(described_class.lookup(:a)).to be_nil
      expect(described_class.registered?(:a)).to be(false)
    end
  end
end
