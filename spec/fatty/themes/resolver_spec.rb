# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Themes::Resolver do
  describe "theme inheritance" do
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

      expect(theme[:roles][:input])
        .to eq(
              fg: "white",
              bg: "navy",
              attrs: [:bold],
            )
    end
  end

  describe "role inheritance" do
    it "uses default role parents when no explicit role inherit is set" do
      registry = Fatty::Themes::Registry.new
      registry.add({
                     name: :theme,
                     inherit: nil,
                     roles: {
                       output: { fg: "white", bg: "navy" },
                       popup: { fg: "yellow" },
                       popup_frame: { border: :double, corners: :rounded },
                     },
                     markdown: {},
                   })

      theme = Fatty::Themes::Resolver.resolve(registry, :theme)

      expect(theme[:roles][:popup_frame])
        .to eq(
              fg: "yellow",
              bg: "navy",
              border: :double,
              corners: :rounded,
            )
    end

    it "allows explicit role inherit to override the default parent" do
      registry = Fatty::Themes::Registry.new
      registry.add({
                     name: :theme,
                     inherit: nil,
                     roles: {
                       output: { fg: "white", bg: "navy" },
                       region: { fg: "black", bg: "yellow" },
                       match_current: { inherit: :output, fg: "red" },
                     },
                     markdown: {},
                   })

      theme = Fatty::Themes::Resolver.resolve(registry, :theme)

      expect(theme[:roles][:match_current]).to eq(
                                                 fg: "red",
                                                 bg: "navy",
                                               )
    end

    it "allows explicit nil role inherit to disable default parent inheritance" do
      registry = Fatty::Themes::Registry.new
      registry.add({
                     name: :theme,
                     inherit: nil,
                     roles: {
                       output: { fg: "white", bg: "navy" },
                       popup: { fg: "yellow" },
                       popup_frame: { inherit: nil, border: :ascii },
                     },
                     markdown: {},
                   })

      theme = Fatty::Themes::Resolver.resolve(registry, :theme)

      expect(theme[:roles][:popup_frame]).to eq(
                                               border: :ascii,
                                             )
    end

    it "detects role inheritance cycles" do
      registry = Fatty::Themes::Registry.new
      registry.add({
                     name: :theme,
                     inherit: nil,
                     roles: {
                       one: { inherit: :two, fg: "white" },
                       two: { inherit: :one, bg: "black" },
                     },
                     markdown: {},
                   })

      expect {
        Fatty::Themes::Resolver.resolve(registry, :theme)
      }.to raise_error(Fatty::Themes::InheritanceCycleError)
    end
  end
end
