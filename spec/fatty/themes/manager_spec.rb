# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Themes::Manager do
  around do |example|
    current = Fatty::Themes::Manager.instance_variable_get(:@current)
    warning = Fatty::Themes::Manager.instance_variable_get(:@warning)
    example.run
  ensure
    Fatty::Themes::Manager.instance_variable_set(:@current, current)
    Fatty::Themes::Manager.instance_variable_set(:@warning, warning)
  end

  it "persists a validated theme selection" do
    allow(Fatty::Themes::Manager).to receive(:theme_names).and_return([:terminal, :nordic])
    expect(Fatty::Config).to receive(:set_preference).with(:theme, :nordic).and_return(true)

    expect(Fatty::Themes::Manager.set(:nordic)).to eq(:nordic)
  end

  it "does not persist an unknown theme" do
    allow(Fatty::Themes::Manager).to receive(:theme_names).and_return([:terminal])
    allow(Fatty::Themes::Manager).to receive(:current).and_return(:terminal)
    expect(Fatty::Config).not_to receive(:set_preference)

    expect(Fatty::Themes::Manager.set(:missing)).to eq(:terminal)
  end
end
