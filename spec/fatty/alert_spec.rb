module Fatty
  RSpec.describe Alert do
    it "requires the message parameter" do
      expect { Alert.new }.to raise_error(ArgumentError)
    end

    it "initializes with just the message parameter" do
      a = Alert.new(message: "hello, world")
      expect(a).to be_a(Alert)
      expect(a.message).to eq('hello, world')
      expect(a.level).to eq(:info)
      expect(a).not_to be_sticky
    end

    it "initializes using .info with just the message parameter" do
      a = Alert.info("hello, world")
      expect(a).to be_a(Alert)
      expect(a.message).to eq('hello, world')
      expect(a.level).to eq(:info)
      expect(a).not_to be_sticky
    end

    it "initializes using .warning with just the message parameter" do
      a = Alert.warning("hello, world")
      expect(a).to be_a(Alert)
      expect(a.message).to eq('hello, world')
      expect(a.level).to eq(:warning)
      expect(a).not_to be_sticky
    end

    it "initializes using .error with just the message parameter" do
      a = Alert.error("hello, world")
      expect(a).to be_a(Alert)
      expect(a.message).to eq('hello, world')
      expect(a.level).to eq(:error)
      expect(a).not_to be_sticky
    end

    it "initializes non-sticky with all parameters" do
      a = Alert.new(
        message: "hello, world",
        level: :debug,
        details: { one: "1", two: "2" },
      )
      expect(a).to be_a(Alert)
      expect(a.message).to eq('hello, world')
      expect(a.level).to eq(:debug)
      expect(a.details).to be_a(Hash)
      expect(a).not_to be_sticky
    end

    it "initializes sticky with all parameters" do
      a = Alert.new(message: "hello, world", level: :debug, details: {one: "1", two: "2"}, sticky: true)
      expect(a).to be_a(Alert)
      expect(a.level).to eq(:debug)
      expect(a.details).to be_a(Hash)
      expect(a).to be_sticky
    end

  end
end
