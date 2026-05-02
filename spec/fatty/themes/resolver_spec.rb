# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Themes::Resolver do
  it "deep merges child roles over inherited roles" do
    registry = Fatty::Themes::Registry.new
    registry.add({
      name: :base,
      inherit: nil,
      roles: {
        input: { fg: "white", bg: "black", attrs: [:bold] },
      },
      markdown: {},
    })

    registry.add({
      name: :child,
      inherit: :base,
      roles: {
        input: { bg: "navy" },
      },
      markdown: {},
    })

    theme = Fatty::Themes::Resolver.resolve(registry, :child)

    expect(theme[:roles][:input]).to eq(
      fg: "white",
      bg: "navy",
      attrs: [:bold],
    )
  end

  it "detects missing parents" do
    registry = Fatty::Themes::Registry.new
    registry.add({
      name: :child,
      inherit: :missing,
      roles: {},
      markdown: {},
    })

    expect {
      Fatty::Themes::Resolver.resolve(registry, :child)
    }.to raise_error(Fatty::Themes::MissingThemeError)
  end

  it "detects inheritance cycles" do
    registry = Fatty::Themes::Registry.new
    registry.add({ name: :a, inherit: :b, roles: {}, markdown: {} })
    registry.add({ name: :b, inherit: :a, roles: {}, markdown: {} })

    expect {
      Fatty::Themes::Resolver.resolve(registry, :a)
    }.to raise_error(Fatty::Themes::InheritanceCycleError)
  end
end
