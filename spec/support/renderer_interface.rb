# frozen_string_literal: true

module Fatty
  RSpec.shared_examples "renderer interface" do
    describe "api" do
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

      it "parses ANSI styling in the prompt into styled segments" do
        field = instance_double(
          InputField,
          prompt_text: "\e[31mred\e[0m> ",
          buffer: instance_double(
            InputBuffer,
            text: "hello",
            virtual_suffix: "",
            region_range: nil,
          ),
        )
        segments = renderer.send(
          :field_segments,
          field,
          base_role: :input,
        )
        expect(segments.map { |segment| segment[:text] }).to eq(["red", "> ", "hello"])
        expect(segments[0][:style].fg).to eq(1)
        expect(segments[1][:style].fg).to be_nil
        expect(segments[2]).to eq(text: "hello", role: :input)
      end
    end
  end
end
