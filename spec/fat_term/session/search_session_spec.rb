# frozen_string_literal: true

require "spec_helper"

module FatTerm
  RSpec.describe SearchSession do
    describe "regex toggle" do
      it "toggles regex mode and updates the prompt" do
        s = SearchSession.new(direction: :forward, regex: false)

        expect(s.regex).to eq(false)
        expect(s.field.prompt_text).to include("Search string")

        cmds = s.handle_action(:search_toggle_regex, [], terminal: nil, event: nil)
        expect(cmds).to eq([])
        expect(s.regex).to eq(true)
        expect(s.field.prompt_text).to include("Regex")

        s.handle_action(:search_toggle_regex, [], terminal: nil, event: nil)
        expect(s.regex).to eq(false)
        expect(s.field.prompt_text).to include("Search string")
      end
    end
  end
end
