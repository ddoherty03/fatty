module Fatty
  RSpec.describe Alert do
    it "requires the text parameter" do
      expect { Alert.new }.to raise_error(ArgumentError)
    end

    it "initializes with just the text parameter" do
      a = Alert.new(text: "hello, world")
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:info)
      expect(a.format).to eq(" ℹ  hello, world")
      expect(a).not_to be_sticky
    end

    it "initializes using .good with just the text parameter" do
      a = Alert.good("hello, world")
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:good)
      expect(a.format).to eq(" ✔  hello, world")
      expect(a).not_to be_sticky
    end

    it "initializes using .info with just the text parameter" do
      a = Alert.info("hello, world")
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:info)
      expect(a.format).to eq(" ℹ  hello, world")
      expect(a).not_to be_sticky
    end

    it "initializes using .warn with just the text parameter" do
      a = Alert.warn("hello, world")
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:warn)
      expect(a.format).to eq(" ⚠  hello, world")
      expect(a).not_to be_sticky
    end

    it "initializes using .error with just the text parameter" do
      a = Alert.error("hello, world")
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:error)
      expect(a.format).to eq(" ✖  hello, world")
      expect(a).not_to be_sticky
    end

    it "initializes non-sticky with all parameters" do
      a = Alert.new(
        text: "hello, world",
        role: :info,
        details: { key: "h", meta: true, shift: false },
      )
      expect(a).to be_a(Alert)
      expect(a.text).to eq('hello, world')
      expect(a.role).to eq(:info)
      expect(a.details).to be_a(Hash)
      expect(a.format).to eq(" ℹ  hello, world (key=h shift=false meta=true)")
      expect(a).not_to be_sticky
    end

    it "initializes sticky with all parameters" do
      a = Alert.new(
        text: "hello, world",
        role: :error,
        details: { one: "1", two: "2" },
        sticky: true,
      )
      expect(a).to be_a(Alert)
      expect(a.role).to eq(:error)
      expect(a.details).to be_a(Hash)
      expect(a.format).to eq(" ✖  hello, world (one=1 two=2)")
      expect(a).to be_sticky
    end
  end
end
