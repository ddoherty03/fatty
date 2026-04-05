# frozen_string_literal: true

require "spec_helper"

RSpec.describe FatTerm::PopUpSession do
  describe "#move_selected_by" do
    def build_popup(items)
      FatTerm::PopUpSession.new(
        source: items,
        kind: :completion,
        title: "Completions",
        prompt: "Complete: ",
        order: :as_given,
        selection: :top,
      )
    end

    it "wraps backward from the first item to the last" do
      popup = build_popup(%w[alpha beta gamma])

      popup.instance_variable_set(:@filtered, %w[alpha beta gamma])
      popup.instance_variable_set(:@selected, 0)

      popup.send(:move_selected_by, -1)

      expect(popup.instance_variable_get(:@selected)).to eq(2)
    end

    it "wraps forward from the last item to the first" do
      popup = build_popup(%w[alpha beta gamma])

      popup.instance_variable_set(:@filtered, %w[alpha beta gamma])
      popup.instance_variable_set(:@selected, 2)

      popup.send(:move_selected_by, 1)

      expect(popup.instance_variable_get(:@selected)).to eq(0)
    end
  end

  describe "#call_source" do
    it "returns literal array sources unchanged as an array" do
      popup = FatTerm::PopUpSession.new(source: %w[alpha beta gamma])

      expect(popup.send(:call_source, "alp")).to eq(%w[alpha beta gamma])
    end

    it "calls arity-0 sources with no argument" do
      popup = FatTerm::PopUpSession.new(source: -> { %w[alpha beta] })

      expect(popup.send(:call_source, "ignored")).to eq(%w[alpha beta])
    end

    it "calls arity-1 sources with the query" do
      popup = FatTerm::PopUpSession.new(
        source: ->(q) { [q, q.upcase] }
      )

      expect(popup.send(:call_source, "alp")).to eq(%w[alp ALP])
    end
  end
end
