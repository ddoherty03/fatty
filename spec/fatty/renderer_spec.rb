# frozen_string_literal: true

module Fatty
  RSpec.shared_examples "renderer interface" do
    it "implements the renderer API" do
      expect(renderer).to respond_to(:render_output)
      expect(renderer).to respond_to(:render_input_field)
      expect(renderer).to respond_to(:render_status)
      expect(renderer).to respond_to(:render_alert)
      expect(renderer).to respond_to(:render_pager_field)
      expect(renderer).to respond_to(:render_prompt_popup)
      expect(renderer).to respond_to(:render_popup)
      expect(renderer).to respond_to(:restore_cursor)
      expect(renderer).to respond_to(:invalidate!)
    end
  end
end
