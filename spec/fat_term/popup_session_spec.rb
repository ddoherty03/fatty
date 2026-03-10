# frozen_string_literal: true

require "spec_helper"

RSpec.describe FatTerm::PopUpSession do
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
