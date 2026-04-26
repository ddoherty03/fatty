# frozen_string_literal: true

require "spec_helper"

module Fatty
  RSpec.describe InputSession do
    def prompt(text = "> ")
      Prompt.new { text }
    end

    it "handles :paste by sending the text to the field paste action" do
      field = InputField.new(prompt: prompt("> "))
      session = InputSession.new(
        field: field,
        keymap: KeyMap.new,
      )

      commands = session.update([:cmd, :paste, { text: "aa\nbb" }])

      expect(commands).to eq([])
      expect(field.buffer.text).to eq("aa bb")
    end
  end
end
