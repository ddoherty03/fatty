# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Demo packaging" do
  it "ships both markdown examples referenced by the demo commands" do
    root = File.expand_path("../..", __dir__)
    spec = Gem::Specification.load(File.join(root, "fatty.gemspec"))
    %w[native-markdown.md ox-gfm-markdown.md].each do |name|
      path = "examples/markdown/#{name}"
      expect(spec.files).to include(path)
      expect(File.read(File.join(root, path))).not_to be_empty
    end
  end
end
