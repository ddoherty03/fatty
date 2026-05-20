# frozen_string_literal: true

require "spec_helper"
require_relative "../renderer_spec"

module Fatty
  RSpec.describe Renderer::Truecolor do
    let(:screen) do
      Fatty::Screen.new(rows: 10, cols: 12, status_rows: 1)
    end

    let(:context) do
      instance_double(
        Curses::Context,
        truecolor: true,
        status_win: nil,
        output_win: nil,
        input_win: nil,
        alert_win: nil,
      )
    end

    let(:palette) do
      {
        status: {
          pair: 2,
          fg_rgb: [255, 255, 255],
          bg_rgb: [0, 0, 80],
          attrs: [],
        },
        good: {
          pair: 1,
          fg_rgb: [0, 0, 0],
          bg_rgb: [240, 248, 255],
          attrs: [],
        },
      }
    end

    subject(:renderer) do
      Renderer::Truecolor.new(
        context: context,
        screen: screen,
        palette: palette,
      )
    end

    include_examples "renderer interface"

    it "renders status with truecolor foreground and status background" do
      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_status("good hello", role: :good)
      renderer.finish_frame

      expect(out.string).to include("38;2;0;0;0")
      expect(out.string).to include("48;2;240;248;255")
      expect(out.string).to include("good hello")
      ensure
        $stdout = original_stdout
    end
  end
end
