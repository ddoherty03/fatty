# frozen_string_literal: true

require "ostruct"
require "spec_helper"

RSpec.describe Fatty::OutputSession do
  def update(session, action, **payload)
    session.update(Fatty::Command.session(session.id, action, **payload))
  end

  def apply_action(session, action, *args)
    session.send(:apply_action, action, args, event: nil)
  end

  def init_output_session(session, rows: 5, cols: 80, theme_version: 0)
    output_rect = OpenStruct.new(row: 0, rows: rows, cols: cols)
    screen = instance_double(Fatty::Screen, output_rect: output_rect)
    renderer = instance_double(Fatty::Renderer, screen: screen, theme_version: theme_version)
    terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

    session.init(terminal: terminal)
  end

  def init_output_session(session, rows: 5, cols: 80, theme_version: 0)
    output_rect = OpenStruct.new(row: 0, rows: rows, cols: cols)
    screen = instance_double(Fatty::Screen, output_rect: output_rect)
    renderer = instance_double(Fatty::Renderer, screen: screen, theme_version: theme_version)
    terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

    session.init(terminal: terminal)
    session.update(Fatty::Command.session(session.id, :resize))
  end

  def append_lines(session, count)
    text = (1..count).map { |n| "line #{n}" }.join("\n")
    session.update(Fatty::Command.session(session.id, :append, text: text, follow: false))
  end

  describe "#init" do
    it "stores the terminal and resizes the viewport from the screen output rect" do
      session = Fatty::OutputSession.new

      init_output_session(session, rows: 6, cols: 72)

      expect(session.terminal).to be_a(Fatty::Terminal).or be_present
      expect(session.viewport.height).to eq(6)
      expect(session.viewport.width).to eq(72) if session.viewport.respond_to?(:width)
    end
  end

  describe "#update" do
    it "handles :append" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      update(session, :append, text: "hello", follow: false)

      expect(session.output.lines).to eq(["hello"])
    end

    it "handles :append with mode: :scrolling" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      update(session, :append, text: "hello", mode: :scrolling)

      expect(session.pager.mode).to eq(:scrolling)
    end

    it "handles :append with mode: :paging" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      update(session, :set_mode, mode: :scrolling)
      update(session, :append, text: "hello", mode: :paging)

      expect(session.pager.mode).to eq(:paging)
    end

    it "handles :append with scroll: true" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)

      update(session, :append, text: "old 1\nold 2\nold 3\nold 4\n", mode: :scrolling)
      update(session, :append, text: "new 1\nnew 2", scroll: true, follow: false)

      expect(session.state[Fatty::OutputSession::STATE_LINES])
        .to include("new 1")
    end

    it "handles :set_mode to scrolling" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      update(session, :set_mode, mode: :scrolling)

      expect(session.pager.mode).to eq(:scrolling)
    end

    it "handles :set_mode to paging" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      update(session, :set_mode, mode: :scrolling)
      update(session, :set_mode, mode: :paging)

      expect(session.pager.mode).to eq(:paging)
    end

    it "handles :clear" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      append_lines(session, 3)

      update(session, :clear)

      expect(session.output.lines).to be_empty
      expect(session.viewport.top).to eq(0)
    end

    it "handles :resize" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 7)

      update(session, :resize)

      expect(session.viewport.height).to eq(7)
    end

    it "handles :begin_command" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      append_lines(session, 2)

      update(session, :begin_command)
      update(session, :append, text: "cmd 1\ncmd 2\ncmd 3\ncmd 4", follow: false)

      expect(session).to be_pager_active
      expect(session.state[Fatty::OutputSession::STATE_LINES])
        .to eq(["cmd 1", "cmd 2", "cmd 3", "cmd 4"])
    end

    it "handles :quit_paging" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      append_lines(session, 5)

      commands = update(session, :quit_paging)

      expect(session).not_to be_pager_active
      expect(commands.map(&:action)).to eq([:refresh_layout])
    end

    it "handles :pager_search_set" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\ngamma\ndelta", follow: false)

      commands = update(session, :pager_search_set, pattern: "gamma", direction: :forward)

      expect(commands).to be_empty
      expect(session.highlights).to include(2)
    end

    it "handles :pager_search_step" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\nalpha\nbeta", follow: false)

      update(session, :pager_search_set, pattern: "alpha", direction: :forward)
      update(session, :pager_search_step, direction: :forward)

      expect(session.highlights).to include(2)
    end

    it "handles :pager_isearch_update" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\ngamma", follow: false)

      commands = update(session, :pager_isearch_update, pattern: "gamma", direction: :forward)

      expect(session.highlights).to include(2)
      expect(commands.last.target).to eq(:isearch)
      expect(commands.last.action).to eq(:isearch_set_failed)
      expect(commands.last.payload[:failed]).to be(false)
    end

    it "handles :pager_isearch_step" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\nalpha", follow: false)

      update(session, :pager_isearch_update, pattern: "alpha", direction: :forward)
      commands = update(session, :pager_isearch_step, direction: :forward)

      expect(session.highlights).to include(2)
      expect(commands.last.payload[:failed]).to be(false)
    end

    it "handles :pager_isearch_cancel" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\ngamma", follow: false)

      update(session, :pager_isearch_update, pattern: "gamma", direction: :forward)
      commands = update(session, :pager_isearch_cancel)

      expect(commands.last.target).to eq(:isearch)
      expect(commands.last.action).to eq(:isearch_set_failed)
      expect(commands.last.payload[:failed]).to be(false)
    end

    it "handles :pager_isearch_commit" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\ngamma", follow: false)

      commands = update(session, :pager_isearch_commit, pattern: "gamma", direction: :forward)

      expect(session.highlights).to include(2)
      expect(commands.last.payload[:failed]).to be(false)
    end

    it "ignores unknown commands" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      commands = update(session, :bogus)

      expect(commands).to eq([])
    end

    it "enters paging when appended output exceeds the pager viewport" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      append_lines(session, 5)
      expect(session).to be_pager_active
      expect(session.viewport.height).to eq(4)

      pager_viewport = Fatty::Viewport.new(
        top: session.viewport.top,
        height: session.viewport.height - 1,
      )
      expect(session.state(viewport: pager_viewport)[Fatty::OutputSession::STATE_LINES])
        .to eq(["line 1", "line 2", "line 3"])
    end

    it "quits paging and asks terminal to refresh layout" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      append_lines(session, 5)

      commands = session.update(
        Fatty::Command.session(session.id, :quit_paging)
      )

      expect(session).not_to be_pager_active
      expect(commands.map(&:action)).to include(:refresh_layout)
    end

    it "sets regex search highlights" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 5)
      append_lines(session, 3)

      session.update(
        Fatty::Command.session(
          session.id,
          :pager_search_set,
          pattern: "line \\d",
          regex: true,
          direction: :forward,
        )
      )

      expect(session.highlights).to include(0)
      expect(session.highlights[0]).to include([0, 6, :primary])
    end
  end

  describe "#view" do
    it "renders output when the pager is inactive" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      expect(session.terminal.renderer)
        .to receive(:render_output)
              .with(session)

      session.view
    end

    it "renders output and pager field when the pager is active" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      append_lines(session, 5)

      allow(Curses).to receive(:curs_set)

      expect(session.terminal.renderer)
        .to receive(:render_output)
              .with(session, viewport: instance_of(Fatty::Viewport))

      expect(session.terminal.renderer)
        .to receive(:render_pager_field)
              .with(
                session.pager_field,
                row: 3,
                role: :pager_status,
              )

      session.view
    end
  end

  describe "actions" do
    it "opens forward search" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      commands = apply_action(session, :pager_search_forward)

      searcher = commands.first.payload.fetch(:session)

      expect(commands.first.action).to eq(:push_modal)
      expect(searcher).to be_a(Fatty::SearchSession)
      expect(searcher.direction).to eq(:forward)
      expect(searcher.regex).to be(false)
    end

    it "opens backward search" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      commands = apply_action(session, :pager_search_backward)

      searcher = commands.first.payload.fetch(:session)

      expect(commands.first.action).to eq(:push_modal)
      expect(searcher).to be_a(Fatty::SearchSession)
      expect(searcher.direction).to eq(:backward)
      expect(searcher.regex).to be(false)
    end

    it "opens forward regex search" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      commands = apply_action(session, :pager_regex_search_forward)

      searcher = commands.first.payload.fetch(:session)

      expect(searcher).to be_a(Fatty::SearchSession)
      expect(searcher.direction).to eq(:forward)
      expect(searcher.regex).to be(true)
    end

    it "opens backward regex search" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      commands = apply_action(session, :pager_regex_search_backward)

      searcher = commands.first.payload.fetch(:session)

      expect(searcher).to be_a(Fatty::SearchSession)
      expect(searcher.direction).to eq(:backward)
      expect(searcher.regex).to be(true)
    end

    it "opens forward search as regex when the counter is 4" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      session.counter.push_digit("4")

      commands = apply_action(session, :pager_search_forward)
      searcher = commands.first.payload.fetch(:session)

      expect(searcher.regex).to be(true)
      expect(session.counter.digits).to eq("")
    end

    it "opens backward search as regex when the counter is 4" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      session.counter.push_digit("4")

      commands = apply_action(session, :pager_search_backward)
      searcher = commands.first.payload.fetch(:session)

      expect(searcher.regex).to be(true)
      expect(session.counter.digits).to eq("")
    end

    it "opens forward incremental search" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      update(session, :append, text: "alpha\nbeta\nalpha", follow: false)
      update(session, :pager_search_set, pattern: "alpha", direction: :forward)

      commands = apply_action(session, :pager_isearch_forward)

      isearcher = commands.first.payload.fetch(:session)

      expect(commands.first.action).to eq(:push_modal)
      expect(isearcher).to be_a(Fatty::ISearchSession)
      expect(isearcher.direction).to eq(:forward)
      expect(isearcher.last_pattern).to eq("alpha")
    end

    it "opens backward incremental search" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      update(session, :append, text: "alpha\nbeta\nalpha", follow: false)
      update(session, :pager_search_set, pattern: "alpha", direction: :forward)

      commands = apply_action(session, :pager_isearch_backward)

      isearcher = commands.first.payload.fetch(:session)

      expect(isearcher).to be_a(Fatty::ISearchSession)
      expect(isearcher.direction).to eq(:backward)
      expect(isearcher.last_pattern).to eq("alpha")
    end

    it "repeats pager search forward" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\nalpha\nbeta", follow: false)
      update(session, :pager_search_set, pattern: "alpha", direction: :forward)

      commands = apply_action(session, :pager_search_next)

      expect(commands).to eq([])
      expect(session.highlights).to include(2)
    end

    it "repeats pager search backward" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)
      update(session, :append, text: "alpha\nbeta\nalpha\nbeta", follow: false)
      update(session, :pager_search_set, pattern: "alpha", direction: :forward)
      apply_action(session, :pager_search_next)

      commands = apply_action(session, :pager_search_prev)

      expect(commands).to eq([])
      expect(session.highlights).to include(0)
    end
  end

  describe "#tick" do
    it "returns false when autoscroll is inactive" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      expect(session.tick).to be(false)
    end

    it "advances autoscroll and returns true when movement occurs" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)

      update(session, :append, text: (1..20).map { |n| "line #{n}" }.join("\n"), follow: false)
      update(session, :set_mode, mode: :scrolling)

      before = session.viewport.top

      expect(session.tick).to be(true)
      expect(session.viewport.top).to be > before
    end
  end

  describe "#state" do
    it "uses the supplied viewport instead of always using the session viewport" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 5, cols: 80, theme_version: 7)
      append_lines(session, 6)

      viewport = Fatty::Viewport.new(top: 0, height: 4)

      expect(session.state(viewport: viewport))
        .to eq(
              [
                [0, 4],
                ["line 1", "line 2", "line 3", "line 4"],
                5,
                80,
                nil,
                7,
              ],
            )
    end

    it "changes when the render viewport changes" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      append_lines(session, 6)

      full = Fatty::Viewport.new(top: 0, height: 5)
      pager = Fatty::Viewport.new(top: 0, height: 4)

      expect(session.state(viewport: full)).not_to eq(session.state(viewport: pager))
    end
  end

  ########################################################################################
  # Other public methods
  ########################################################################################

  describe "#pager_active?" do
    it "delegates to the pager active state" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)

      expect(session.pager_active?).to be(false)

      update(session, :append, text: (1..5).map { |n| "line #{n}" }.join("\n"), follow: false)

      expect(session.pager_active?).to be(true)
    end
  end

  describe "#highlights" do
    it "returns nil when no search is active" do
      session = Fatty::OutputSession.new
      init_output_session(session)

      expect(session.highlights).to be_nil
    end

    it "returns visible search highlights from the pager" do
      session = Fatty::OutputSession.new
      init_output_session(session, rows: 4)

      update(session, :append, text: "alpha\nbeta\nalpha\ngamma", follow: false)
      update(session, :pager_search_set, pattern: "alpha", direction: :forward)

      expect(session.highlights).to include(0)
      expect(session.highlights[0]).to include([0, 5, :primary])
    end
  end

  describe "#incrementally_scrollable_from?" do
    it "recognizes a one-line downward scroll" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      append_lines(session, 8)

      prev_state = session.state(viewport: Fatty::Viewport.new(top: 0, height: 4))
      curr_state = session.state(viewport: Fatty::Viewport.new(top: 1, height: 4))

      expect(session.incrementally_scrollable_from?(prev_state, curr_state)).to be(true)
      expect(session.scroll_delta_from(prev_state, curr_state)).to eq(1)
    end

    it "rejects a jump with no positive overlap" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      append_lines(session, 12)

      prev_state = session.state(viewport: Fatty::Viewport.new(top: 0, height: 4))
      curr_state = session.state(viewport: Fatty::Viewport.new(top: 4, height: 4))

      expect(session.incrementally_scrollable_from?(prev_state, curr_state)).to be(false)
    end

    it "rejects upward scrolling" do
      session = Fatty::OutputSession.new
      init_output_session(session)
      append_lines(session, 8)

      prev_state = session.state(viewport: Fatty::Viewport.new(top: 1, height: 4))
      curr_state = session.state(viewport: Fatty::Viewport.new(top: 0, height: 4))

      expect(session.incrementally_scrollable_from?(prev_state, curr_state)).to be(false)
      expect(session.scroll_delta_from(prev_state, curr_state)).to eq(-1)
    end
  end
end
