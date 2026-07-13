# frozen_string_literal: true

require "spec_helper"
require_relative "../renderer_spec"

class CursesRendererSpecWindow
  attr_reader :writes
  attr_reader :maxx
  attr_reader :maxy

  def initialize(maxx: 20, maxy: 1)
    @maxx = maxx
    @maxy = maxy
    @writes = []
  end

  def bkgdset(attr) = @writes << [:bkgdset, attr]
  def erase = @writes << [:erase]
  def setpos(row, col) = @writes << [:setpos, row, col]
  def attrset(attr) = @writes << [:attrset, attr]
  def addstr(text) = @writes << [:addstr, text]
  def noutrefresh = @writes << [:noutrefresh]
  def clrtoeol = @writes << [:clrtoeol]
end

class CursesRendererSpecPopupWindow < CursesRendererSpecWindow
  attr_reader :derived
  attr_reader :closed

  def initialize(maxx: 30, maxy: 6)
    super(maxx: maxx, maxy: maxy)
    @derived = nil
    @closed = false
  end

  def derwin(rows, cols, row, col)
    @writes << [:derwin, rows, cols, row, col]
    @derived = CursesRendererSpecPopupWindow.new(maxx: cols, maxy: rows)
  end

  def close
    @closed = true
    @writes << [:close]
  end
end

module Fatty
  RSpec.describe Renderer::Curses do
    let(:output_win) do
      CursesRendererSpecWindow.new(maxx: 20, maxy: 6)
    end

    let(:status_rect) do
      instance_double(
        Screen::Rect,
        row: 20,
        col: 0,
        rows: 1,
        cols: 20,
      )
    end

    let(:screen) do
      instance_double(
        Screen,
        rows: 24,
        cols: 80,
        status_rect: status_rect,
      )
    end

    let(:palette) do
      {
        output: {
          pair: Fatty::Colors::Pairs::ROLE_TO_PAIR.fetch(:output),
          attrs: [],
        },
        line_number: {
          pair: Fatty::Colors::Pairs::ROLE_TO_PAIR.fetch(:line_number),
          attrs: [],
        },
      }
    end

    let(:input_win) { CursesRendererSpecWindow.new(maxx: 5) }

    let(:curses_context) do
      instance_double(
        Curses::Context,
        palette: palette,
        status_win: status_win,
        input_win: input_win,
        output_win: output_win,
        reset_ansi_pairs!: nil,
      )
    end

    let(:status_win) { CursesRendererSpecWindow.new(maxx: 20) }

    subject(:renderer) do
      Renderer::Curses.new(
        screen: screen,
        palette: palette,
        context: curses_context,
      )
    end

    it_behaves_like "renderer interface"

    it "renders status segment arrays without collapsing them with to_s" do
      allow(curses_context).to receive(:status_win).and_return(status_win)
      allow(::Curses).to receive(:color_pair) { |pair| pair }

      terminal = instance_double(Fatty::Terminal, renderer: renderer, screen: screen)
      status = Fatty::StatusSession.new
      status.init(terminal: terminal)
      status.update(
        Fatty::Command.session(
          :status,
          :show,
          text: [
            "Loading ",
            { text: "+", role: :good },
            { text: "!", role: :error },
          ],
          role: :status,
        ),
      )

      renderer.render_status(status)

      added = status_win.writes
                .select { |op, _text| op == :addstr }
                .map { |_op, text| text }

      expect(added.join).to start_with("Loading +!")
      expect(added.join.length).to eq(20)
    end

    it "strips ANSI before rendering popup text through curses" do
      popup_win = CursesRendererSpecPopupWindow.new(maxx: 30, maxy: 6)
      field = instance_double(
        InputField,
        prompt_text: "> ",
        cursor_x: 0,
        buffer: instance_double(
          InputBuffer,
          text: "",
          cursor: 0,
          virtual_suffix: "",
          region_active?: false,
          region_range: nil,
        ),
      )

      session = instance_double(
        PopUpSession,
        win: popup_win,
        title: "\e[31mTitle\e[0m",
        message: "\e[32mMessage\e[0m",
        counts: nil,
        displayed: ["\e[33mChoice\e[0m"],
        current: 0,
        selected_labels: [],
        field: field,
        scroll_start: 0,
        counts_present?: false,
        filter_present?: true,
        gutter_for: "▶ ",
        state: [
          "\e[31mTitle\e[0m",
          "\e[32mMessage\e[0m",
          ["\e[33mChoice\e[0m"],
          0,
          [],
          0,
          field,
        ],
      )

      renderer.render_popup(session: session)

      all_added = [popup_win, popup_win.derived]
                    .compact
                    .flat_map(&:writes)
                    .select { |op, _text| op == :addstr }
                    .map { |_op, text| text }

      expect(all_added.join).to include("Title")
      expect(all_added.join).to include("Message")
      expect(all_added.join).to include("Choice")
      expect(all_added.join).not_to include("\e[")
      expect(popup_win.derived.closed).to be(true)
    end

    it "renders ANSI-colored prompt segments through curses attributes" do
      win = CursesRendererSpecWindow.new(maxx: 20)

      allow(curses_context).to receive(:input_win).and_return(win)
      allow(curses_context).to receive(:ansi_pair_for).and_return(64)
      allow(::Curses).to receive(:colors).and_return(256)
      allow(::Curses).to receive(:color_pair) { |pair| pair }
      allow(::Curses).to receive(:color_pair).with(64).and_return(0x6400)

      # field = InputField.new(prompt: "\e[31mred\e[0m> ")
      field = InputField.new(prompt: "\e[31mred\e[0m> ")
      field.buffer.insert("hello")

      renderer.render_input_field(field)

      added = win.writes
                .select { |operation, _value| operation == :addstr }
                .map { |_operation, value| value }

      expect(added.join).to include("red> hello")
      expect(added.join).not_to include("\e[")
      expect(curses_context)
        .to have_received(:ansi_pair_for)
              .with(
                1,
                nil,
                fallback_pair_id: Fatty::Colors::Pairs::ROLE_TO_PAIR.fetch(:input),
              )
    end

    it "renders original zero-padded line numbers for narrowed visible lines" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 2, text: "second"),
        Fatty::OutputSession::VisibleLine.new(number: 117, text: "later"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: Array.new(120, ""),
      )
      viewport = Fatty::Viewport.new(height: 6)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: true,
        incrementally_scrollable_from?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          6,
          20,
          nil,
          renderer.theme_version,
          true,
        ]
      end
      allow(::Curses).to receive(:color_pair) { |pair| pair }

      renderer.render_output(session)

      added = output_win.writes
                .select { |operation, _value| operation == :addstr }
                .map { |_operation, value| value }

      expect(added).to include("002: ")
      expect(added).to include("117: ")
      expect(added.join).to include("second")
      expect(added.join).to include("later")
    end

    it "uses the line_number color pair for the output gutter" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 1, text: "output"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: ["output"],
      )
      viewport = Fatty::Viewport.new(height: 6)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: true,
        incrementally_scrollable_from?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          6,
          20,
          nil,
          renderer.theme_version,
          true,
        ]
      end
      allow(::Curses).to receive(:color_pair) { |pair| pair }

      renderer.render_output(session)

      line_number_pair =
        Fatty::Colors::Pairs::ROLE_TO_PAIR.fetch(:line_number)

      gutter_index = output_win.writes.index([:addstr, "1: "])
      expect(gutter_index).not_to be_nil
      expect(output_win.writes[0...gutter_index])
        .to include([:attrset, line_number_pair])
    end

    it "does not render a gutter when line numbers are disabled" do
      visible_lines = [
        Fatty::OutputSession::VisibleLine.new(number: 117, text: "output"),
      ]
      output = instance_double(
        Fatty::OutputBuffer,
        lines: Array.new(120, ""),
      )
      viewport = Fatty::Viewport.new(height: 6)
      session = instance_double(
        Fatty::OutputSession,
        visible_lines: visible_lines,
        output: output,
        viewport: viewport,
        highlights: nil,
        line_numbers?: false,
        incrementally_scrollable_from?: false,
      )
      allow(session).to receive(:state) do |viewport:|
        [
          viewport.state,
          viewport.slice(visible_lines),
          6,
          20,
          nil,
          renderer.theme_version,
          false,
        ]
      end
      allow(::Curses).to receive(:color_pair) { |pair| pair }

      renderer.render_output(session)

      added = output_win.writes
                .select { |operation, _value| operation == :addstr }
                .map { |_operation, value| value }

      expect(added.join).to include("output")
      expect(added).not_to include("117: ")
    end

    it "clamps restored input cursor position to the input window width" do
      field = instance_double(InputField, cursor_x: 99)

      renderer.restore_cursor(field)

      expect(input_win.writes).to include([:setpos, 0, 4])
    end
  end
end
