# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe Counter do
    describe "#active? / #value" do
      it "starts inactive" do
        c = Counter.new
        expect(c.active?).to be(false)
        expect(c.value).to be_nil
      end

      it "accumulates digits into a number" do
        c = Counter.new
        c.push_digit(1)
        c.push_digit(2)
        c.push_digit(3)
        expect(c.active?).to be(true)
        expect(c.value).to eq(123)
      end
    end

    describe "#consume" do
      it "returns default when inactive and does not activate" do
        c = Counter.new
        expect(c.consume(default: 1)).to eq(1)
        expect(c.active?).to be(false)
      end

      it "returns the value and clears when active" do
        c = Counter.new
        c.push_digit(4)
        c.push_digit(2)
        expect(c.consume(default: 1)).to eq(42)
        expect(c.active?).to be(false)
        expect(c.value).to be_nil
      end
    end

    describe "#clear!" do
      it "clears digits" do
        c = Counter.new
        c.push_digit(9)
        expect(c.active?).to be(true)
        c.clear!
        expect(c.active?).to be(false)
      end
    end

    describe "digit clamping" do
      it "accepts non-integer input but stores digit strings" do
        c = Counter.new
        c.push_digit("7")
        expect(c.value).to eq(7)
      end

      it "caps length to MAX_DIGITS" do
        c = Counter.new
        (Counter::MAX_DIGITS + 3).times { c.push_digit(1) }
        expect(c.digits.length).to eq(Counter::MAX_DIGITS)
      end
    end

    describe "#universal_argument!" do
      it "starts at 4 when inactive" do
        c = Counter.new
        c.universal_argument!
        expect(c.value).to eq(4)
      end

      it "multiplies by 4 when active" do
        c = Counter.new
        c.push_digit(3)
        c.universal_argument!
        expect(c.value).to eq(12)
      end
    end
  end
end
