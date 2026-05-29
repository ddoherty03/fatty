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

    let(:palette) { {} }
    let(:input_win) { CursesRendererSpecWindow.new(maxx: 5) }
    let(:curses_context) do
      instance_double(
        Curses::Context,
        palette: palette,
        status_win: status_win,
        input_win: input_win,
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

      renderer.render_status(
        [
          "Loading ",
          { text: "+", role: :good },
          { text: "!", role: :error },
        ],
        role: :status,
      )

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
        selected: 0,
        selected_labels: [],
        field: field,
        scroll_start: 0,
        gutter_for: "▶ ",
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

    it "clamps restored input cursor position to the input window width" do
      field = instance_double(InputField, cursor_x: 99)

      renderer.restore_cursor(field)

      expect(input_win.writes).to include([:setpos, 0, 4])
    end
  end
end
