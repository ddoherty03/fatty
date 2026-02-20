# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe "count injection via ActionEnvironment" do
    around do |example|
      snap = FatTerm::Actions.snapshot
      FatTerm::Actions.reset!
      example.run
    ensure
      FatTerm::Actions.restore(snap)
    end

    let(:target_class) do
      Class.new do
        include FatTerm::Actionable

        attr_reader :calls

        def initialize
          @calls = []
        end

        desc("Action that accepts count:")
        action :__test_scroll_down, on: :field do |count: 1|
          @calls << count
        end

        desc("Action that does not accept count:")
        action :__test_no_count, on: :field do
          @calls << :no_count
        end
      end
    end

    it "injects count: and consumes it when the action accepts count" do
      target = target_class.new
      counter = Counter.new
      counter.push_digit(1).push_digit(2) # 12

      env = ActionEnvironment.new(field: target, counter: counter)

      Actions.call(:__test_scroll_down, env)
      expect(target.calls).to eq([12])
      expect(counter.active?).to be(false)
    end

    it "does not consume the counter if the action does not accept count" do
      target = target_class.new
      counter = Counter.new
      counter.push_digit(7)

      env = ActionEnvironment.new(field: target, counter: counter)

      Actions.call(:__test_no_count, env)
      expect(target.calls).to eq([:no_count])
      expect(counter.active?).to be(true)
      expect(counter.value).to eq(7)
    end

    it "does not override an explicit count kwarg" do
      target = target_class.new
      counter = Counter.new
      counter.push_digit(9)

      env = ActionEnvironment.new(field: target, counter: counter)

      Actions.call(:__test_scroll_down, env, count: 3)
      expect(target.calls).to eq([3])
      expect(counter.active?).to be(true)
      expect(counter.value).to eq(9)
    end
  end
end
