# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::KeybindingsSession do
  it "uses equally sized bordered tables and theme roles for headings and headers" do
    screen = Fatty::Screen.new(rows: 24, cols: 160)
    terminal = instance_double(Fatty::Terminal, screen: screen)
    map = Fatty::KeyMap.new
    map.bind(context: :text, key: :a, action: :page_up)
    map.bind(context: :input, key: :b, action: :history_prev)
    session = Fatty::KeybindingsSession.new(keymap: map)
    session.init(terminal: terminal).each { |command| session.update(command) }

    lines = session.visible_lines
    tables = lines.select { |line| line.text.start_with?("  ┌", "  │", "  ├", "  └") }
    expect(tables.map { |line| Fatty::Ansi.visible_length(line.text) }.uniq).to eq([83])
    expect((lines - tables).map { |line| Fatty::Ansi.visible_length(line.text) }.max).to be <= 80
    binding = lines.find { |line| line.text.include?("│ a ") }
    expect(binding.text).to include("│ page_up ", "│ Page up in output ")
    expect(tables.count { |line| line.text.start_with?("  ┌") }).to eq(2)
    expect(tables.count { |line| line.text.start_with?("  └") }).to eq(2)
    expect(lines.first.fragments.map(&:role)).to eq([:markdown_h1])
    ["text", "input"].each do |context|
      expect(lines.find { |line| line.text == "In the #{context} context:" }.fragments.map(&:role)).to eq([:markdown_h2])
    end
    headers = lines.select { |line| line.text.start_with?("  │ Key ") }
    expect(headers.first.text).to match(/│ Key +│ Action +│ Description +│/)
    expect(headers.map { |line| line.fragments.map(&:role) }).to eq([[:markdown_table_header], [:markdown_table_header]])
    expect(session.output.lines.join).not_to include("\e[")
  end

  it "keeps the longest default action on one line in both 80-column and wider terminals" do
    [80, 160].each do |cols|
      screen = Fatty::Screen.new(rows: 24, cols: cols)
      terminal = instance_double(Fatty::Terminal, screen: screen)
      session = Fatty::KeybindingsSession.new(keymap: Fatty::Keymaps.emacs)
      session.init(terminal: terminal).each { |command| session.update(command) }

      expect(session.output.lines.any? { |line| line.include?("│ pager_regex_search_backward │") }).to be(true)
      expect(session.output.lines.map { |line| Fatty::Ansi.visible_length(line) }.max).to eq([cols, 83].min)
    end
  end

  it "uses the configured quit binding even after switching to scrolling" do
    map = Fatty::Keymaps.emacs
    map.bind(context: :paging, key: :x, action: :quit_paging)
    session = Fatty::KeybindingsSession.new(keymap: map)
    session.pager.set_to_scrolling

    commands = session.update(Fatty::Command.session(session.id, :key, event: key(:x)))

    expect(commands.map(&:action)).to eq([:pop_modal])
  end

  it "does not stack another help session when help is already open" do
    session = Fatty::KeybindingsSession.new(keymap: Fatty::Keymaps.emacs)

    commands = session.update(Fatty::Command.session(session.id, :key, event: key(:'?', meta: true)))

    expect(commands).to be_empty
  end

  it "updates the viewport after a terminal resize" do
    screen = Fatty::Screen.new(rows: 24, cols: 80)
    terminal = instance_double(Fatty::Terminal, screen: screen)
    session = Fatty::KeybindingsSession.new(keymap: Fatty::Keymaps.emacs)
    session.init(terminal: terminal)
    screen.resize(rows: 12, cols: 60)

    session.handle_resize.each { |command| session.update(command) }

    expect(session.viewport.height).to eq(screen.output_rect.rows)
  end
end
