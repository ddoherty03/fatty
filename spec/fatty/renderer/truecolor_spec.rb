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
        output: {
          pair: 1,
          fg_rgb: [220, 220, 220],
          bg_rgb: [0, 0, 0],
          attrs: [],
        },
        line_number: {
          pair: 2,
          fg_rgb: [120, 120, 120],
          bg_rgb: [255, 165, 0],
          attrs: [],
        },
        status: {
          pair: 3,
          fg_rgb: [255, 255, 255],
          bg_rgb: [0, 0, 80],
          attrs: [],
        },
        good: {
          pair: 4,
          fg_rgb: [0, 0, 0],
          bg_rgb: [240, 248, 255],
          attrs: [],
        },
        input: {
          pair: 5,
          fg_rgb: [220, 220, 220],
          bg_rgb: [0, 0, 0],
          attrs: [],
        },
      }
    end

    let(:terminal) do
      instance_double(Fatty::Terminal, renderer: renderer, screen: screen)
    end

    subject(:renderer) do
      Renderer::Truecolor.new(
        context: context,
        screen: screen,
        palette: palette,
      )
    end

    it_behaves_like "renderer interface"

    it "renders status with truecolor foreground and status background" do
      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      status = Fatty::StatusSession.new
      status.init(terminal: terminal)
      status.update(
        Fatty::Command.session(:status, :show, text: "Ready", role: :good),
      )

      renderer.render_status(status)
      renderer.finish_frame

      expect(out.string).to include("38;2;0;0;0")
      expect(out.string).to include("48;2;240;248;255")
      expect(out.string).to include("Ready")
      ensure
        $stdout = original_stdout
    end

    it "renders ANSI colors embedded in the input prompt" do
      field = InputField.new(prompt: "\e[31mred\e[0m> ")
      field.buffer.insert("hello")

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_input_field(field)
      renderer.finish_frame

      expect(out.string).to include("\e[38;2;")
      expect(out.string).to include("red")
      expect(out.string).to include("> ")
      expect(out.string).to include("hello")
      ensure
        $stdout = original_stdout
    end

    it "renders output using its semantic role" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(
          number: 1,
          text: "Good news",
          fragments: [
            Fatty::OutputBuffer::Fragment.new(
              text: "Good news",
              role: :good,
            ),
          ],
        ),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: ["Good news"],
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          false,
        ]
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("Good news")
      expect(out.string).to include("38;2;0;0;0")
      expect(out.string).to include("48;2;240;248;255")
      ensure
        $stdout = original_stdout
    end

    it "renders output using semantic role attributes" do
      palette[:good][:attrs] = [:bold]

      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(
          number: 1,
          text: "Good news",
          fragments: [
            Fatty::OutputBuffer::Fragment.new(
              text: "Good news",
              role: :good,
            ),
          ],
        ),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: ["Good news"],
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          false,
        ]
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("Good news")
      expect(out.string).to include("\e[1;")
      ensure
        $stdout = original_stdout
    end

    it "renders output with an unknown semantic role using the output role" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(
          number: 1,
          text: "Visible",
          fragments: [
            Fatty::OutputBuffer::Fragment.new(
              text: "Visible",
              role: :missing,
            ),
          ],
        ),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: ["Visible"],
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          false,
        ]
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("Visible")
      expect(out.string).to include("38;2;220;220;220")
      ensure
        $stdout = original_stdout
    end

    it "renders original zero-padded line numbers for narrowed visible lines" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 2, text: "second match"),
        Fatty::OutputSession::VisibleLine.new(number: 117, text: "later match"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: Array.new(120, ""),
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: true,
        state: [
          viewport.state,
          visible_lines,
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          true,
        ],
      )

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("002: ")
      expect(out.string).to include("117: ")
      expect(out.string).to include("second")
      expect(out.string).to include("later")
      ensure
        $stdout = original_stdout
    end

    it "renders the line-number gutter with the line_number theme role" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 1, text: "output"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: ["output"],
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: true,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          true,
        ]
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("48;2;255;165;0")
      expect(out.string).to include("1: ")
      ensure
        $stdout = original_stdout
    end

    it "does not render a gutter when line numbers are disabled" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 117, text: "output"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: Array.new(120, ""),
      )
      viewport = Fatty::Viewport.new(height: screen.output_rect.rows)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          screen.output_rect.rows,
          screen.output_rect.cols,
          nil,
          renderer.theme_version,
          false,
        ]
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.begin_frame
      renderer.render_output(session)
      renderer.finish_frame

      expect(out.string).to include("output")
      expect(out.string).not_to include("117: ")
      ensure
        $stdout = original_stdout
    end

    it "clamps restored input cursor position to the input rect width" do
      field = instance_double(InputField, cursor_x: 99)

      renderer.begin_frame
      renderer.restore_cursor(field)

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      renderer.finish_frame

      row = screen.input_rect.row + 1
      col = screen.input_rect.col + screen.input_rect.cols

      expect(out.string).to include("\e[#{row};#{col}H")
      ensure
        $stdout = original_stdout
    end

    describe "#style" do
      let(:renderer) { Fatty::Ansi::Renderer.new }

      it "wraps text in the specified palette role" do
        palette = {
          warn: {
            fg_rgb: [255, 255, 0],
            bg_rgb: [10, 20, 30],
            attrs: [:bold],
          },
        }

        result = renderer.style(
          "Careful",
          role: :warn,
          palette: palette,
        )

        expect(result).to eq(
                            "\e[0m\e[1m\e[38;2;255;255;0m" \
                            "\e[48;2;10;20;30mCareful\e[0m",
                          )
      end

      it "returns plain text when the role is unavailable" do
        result = renderer.style(
          "Careful",
          role: :warn,
          palette: {},
        )

        expect(result).to eq("Careful")
      end
    end
  end
end
