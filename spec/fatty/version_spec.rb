# frozen_string_literal: true

module Fatty
  RSpec.describe 'VERSION' do
    it 'has a version number' do
      expect(VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
