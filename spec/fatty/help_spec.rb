# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fatty::Help do
  it "puts text immediately before input, followed by the other contexts" do
    map = Fatty::KeyMap.new
    [:paging, :input, :text, :popup].each do |context|
      map.bind(context: context, key: :a, action: :move_right)
    end

    markdown = Fatty::Help.keybindings(map)

    expect(markdown.lines.grep(/^## /).map(&:chomp)).to eq(
      ["## In the text context:", "## In the input context:", "## In the paging context:", "## In the popup context:"],
    )
    expect(markdown).to start_with("# Current keybindings\n")
  end

  it "reports loaded overrides, action descriptions, arguments, and mouse bindings by context" do
    map = Fatty::KeyMap.new
    map.bind(context: :input, key: :x, meta: true, action: :move_left)
    map.bind(context: :input, key: :x, meta: true, action: :move_right)
    map.bind(context: :paging, key: :'3', action: [:count_digit, 3])
    map.bind_mouse(context: :paging, button: :scroll_up, action: :page_up)

    markdown = Fatty::Help.keybindings(map)
    expect(markdown).to include("| Key | Action | Description |")
    text = Fatty::Ansi.strip(Fatty::Markdown.render(markdown))

    expect(text).to include("input", "paging", "M-x", "move_right", "count_digit 3", "scroll_up", "page_up")
    descriptions = text.lines.filter_map { |line| line.split("│")[3]&.strip }.join(" ")
    expect(descriptions).to include(Fatty::Actions.lookup(:move_right).fetch(:doc))
    expect(text).not_to include("move_left")
  end

  it "keeps punctuation keys literal and wraps tables to the requested width" do
    map = Fatty::KeyMap.new
    [:'|', :'`', :'*', :'_', :'<'].each do |key|
      map.bind(context: :input, key: key, action: :move_right)
    end

    text = Fatty::Ansi.strip(Fatty::Markdown.render(Fatty::Help.keybindings(map, width: 40), width: 40))

    ["|", "`", "*", "_", "<"].each do |key|
      expect(text).to include("│ #{key} ")
    end
    expect(text.lines.map { |line| line.chomp.length }.max).to be <= 40
    expect(text).to include("move_right")
  end
end
