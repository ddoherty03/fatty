# frozen_string_literal: true

require "rouge"
require "cgi"

module Fatty
  class AnsiRenderer < Redcarpet::Render::Base
    HARD_BREAK = "\uE000"

    def initialize(width: 80, palette: nil, theme: nil, truecolor: false)
      super()
      @width = width.to_i
      @palette = palette || {}
      @theme = theme || {}
      @truecolor = truecolor
    end

    def block_code(code, language)
      lexer = rouge_lexer(language.to_s, code.to_s)
      formatter = rouge_formatter
      gutter = md("│ ", :markdown_code_gutter)

      highlighted = formatter.format(lexer.lex(code.to_s))
      lines = highlighted.lines.map(&:chomp)

      lines.pop while lines.any? && Fatty::Ansi.plain_text(lines.last).strip.empty?

      body = lines.map { |line|
        "#{gutter}#{line}"
      }.join("\n")

      "#{body}\n\n"
    end

    def normal_text(text)
      text = render_inline_html(CGI.unescapeHTML(text.to_s))
      text
    end

    def raw_html(html)
      text = CGI.unescapeHTML(html.to_s)
      render_inline_html(text)
    end

    def render_inline_html(text)
      text.to_s
        .gsub(%r{<br\s*/?>}i, HARD_BREAK)
        .gsub(%r{<span\s+class=["']underline["']>(.*?)</span>}m) do
          md(Regexp.last_match(1), :markdown_underline)
      end
    end

    # Curses does not support strike-through, but this emulates it with
    # unicode "combining characters" by adding a "Long Stroke Overlay"
    # (U+0366) after each character, which overlays each with a strike-through
    # overlay.  We just had to make sure that Ansi.visible_length takes these
    # into account in computing width.
    def strikethrough(text)
      text.to_s.each_char.map { |ch| "#{ch}\u0336" }.join
    end

    def link(link, _title, content)
      label = content.to_s.empty? ? link : content
      "#{md(label, :markdown_link)} #{md("<#{link}>", :markdown_url)}"
    end

    def codespan(code)
      md(code.to_s, :markdown_code)
    end

    def double_emphasis(text)
      md(text.to_s, :markdown_strong)
    end

    # Curses does not reliably render true italics, so we use underline instead.
    def emphasis(text)
      md(text.to_s, :markdown_emphasis)
    end

    def highlight(text)
      md(text.to_s, :markdown_highlight)
    end

    def autolink(link, _link_type)
      md(link.to_s, :markdown_link)
    end

    def quote(text)
      "“#{text}”"
    end

    def block_quote(quote)
      gutter = md("│ ", :markdown_quote_gutter)
      quote = CGI.unescapeHTML(quote.to_s)
      paragraphs = quote.to_s.split(/\n{2,}/).map do |para|
        text = para.lines.map(&:strip).reject(&:empty?).join(" ")

        if text.empty?
          gutter
        else
          wrap(text, first_prefix: gutter, rest_prefix: gutter)
        end
      end
      paragraphs.join("\n#{gutter}\n") + "\n\n"
    end

    def header(text, level)
      body =
        case level
        when 1
          h1(text)
        when 2
          h2(text)
        when 3
          h3(text)
        else
          Rainbow(text.to_s).bright.to_s
        end
      "#{body}\n\n"
    end

    def hrule
      "#{md(TABLE_DASH * @width.to_i.clamp(20, 80), :markdown_hrule)}\n\n"
    end

    def linebreak
      "\n"
    end

    def paragraph(text)
      "#{wrap(text)}\n\n"
    end

    def list(contents, _type)
      "#{contents}\n"
    end

    def list_item(text, _type)
      text = render_inline_html(CGI.unescapeHTML(text.to_s))
      head, rest = text.to_s.strip.split(/\n+/, 2)
      out = wrap(
        head.to_s.strip,
        first_prefix: "  • ",
        rest_prefix: "    ",
      )

      if rest && !rest.empty?
        out << "\n"
        out << indent_block(rest.rstrip, "  ")
      end

      out << "\n"
      out
    end

    def indent_block(text, prefix)
      text.to_s.lines.map { |line|
        if line.strip.empty?
          line
        else
          "#{prefix}#{line}"
        end
      }.join
    end

    CELL_SEP = "\u001F"
    TABLE_BAR = "│"
    TABLE_DASH = "─"

    def table(header, body)
      rows = (header + body).lines.map do |line|
        line.chomp.split(CELL_SEP, -1)
      end

      widths = table_widths(rows)

      rendered = rows.each_with_index.map do |row, index|
        header_row = index.zero?

        line = render_table_row_cells(row, widths, header: header_row)

        if header_row
          [line, render_table_separator(widths)].join("\n")
        else
          line
        end
      end

      rendered.join("\n") + "\n\n"
    end

    def table_row(content)
      content.chomp.delete_suffix(CELL_SEP) + "\n"
    end

    def table_cell(content, _alignment)
      inline(content.strip) + CELL_SEP
    end

    def table_widths(rows)
      widths = []

      rows.each do |row|
        row.each_with_index do |cell, index|
          width = Fatty::Ansi.visible_length(cell)
          widths[index] = [widths[index] || 0, width].max
        end
      end

      widths
    end

    def render_table_row_cells(row, widths, header: false)
      cells = widths.each_with_index.map do |width, index|
        text = row[index].to_s
        text = header ? th(text) : td(text)
        pad_visible(text, width)
      end

      "  │ #{cells.join(' │ ')} │"
    end

    def render_table_separator(widths)
      parts = widths.map do |width|
        TABLE_DASH * (width + 2)
      end

      "  #{TABLE_BAR}#{parts.join(TABLE_BAR)}#{TABLE_BAR}"
    end

    def pad_visible(text, width)
      padding = width - Fatty::Ansi.visible_length(text)
      padding = 0 if padding.negative?
      "#{text}#{' ' * padding}"
    end

    def inline(text)
      text.to_s
    end

    def h1(text)
      md(text.to_s, :markdown_h1)
    end

    def h2(text)
      md(text.to_s, :markdown_h2)
    end

    def h3(text)
      md(text.to_s, :markdown_h3)
    end

    def th(text)
      md(text.to_s, :markdown_table_header)
    end

    def td(text)
      md(text.to_s, :markdown_table_cell)
    end

    def rouge_lexer(language, code)
      lexer =
        if !language.empty?
          Rouge::Lexer.find_fancy(language, code)
        else
          Rouge::Lexer.guess(source: code)
        end

      lexer || Rouge::Lexers::PlainText.new
    rescue StandardError
      Rouge::Lexers::PlainText.new
    end

    private

    # simplecov:disable

    def wrap(text, first_prefix: "", rest_prefix: first_prefix)
      hard_lines = text.to_s.split(HARD_BREAK, -1)

      hard_lines.each_with_index.map { |hard_line, index|
        wrap_soft_line(
          hard_line,
          first_prefix: index.zero? ? first_prefix : rest_prefix,
          rest_prefix: rest_prefix,
        )
      }.join("\n")
    end

    def wrap_soft_line(text, first_prefix: "", rest_prefix: first_prefix)
      width = @width.to_i.clamp(20, 80)

      words = text.to_s.split(/\s+/)
      lines = []
      line = +""

      words.each do |word|
        next if word.empty?

        prefix = lines.empty? ? first_prefix : rest_prefix
        available = width - Fatty::Ansi.visible_length(prefix)
        available = 20 if available < 20

        candidate = line.empty? ? word : "#{line} #{word}"

        if Fatty::Ansi.visible_length(candidate) > available && !line.empty?
          lines << "#{prefix}#{line}"
          line = word.dup
        else
          line = candidate
        end
      end

      unless line.empty?
        prefix = lines.empty? ? first_prefix : rest_prefix
        lines << "#{prefix}#{line}"
      end

      lines.empty? ? first_prefix.rstrip : lines.join("\n")
    end

    def md(text, role)
      spec = @palette[role.to_sym] || {}
      codes = sgr_codes_for(spec)

      if codes.empty?
        text.to_s
      else
        "\e[#{codes.join(';')}m#{text}\e[0m"
      end
    end

    def sgr_codes_for(spec)
      attrs = Array(spec[:attrs] || spec["attrs"]).map(&:to_sym)
      codes = []

      codes << 1 if attrs.include?(:bold)
      codes << 2 if attrs.include?(:dim)
      codes << 3 if attrs.include?(:italic)
      codes << 4 if attrs.include?(:underline)
      codes << 7 if attrs.include?(:reverse)

      fg_rgb = spec[:fg_rgb] || spec["fg_rgb"]
      bg_rgb = spec[:bg_rgb] || spec["bg_rgb"]
      fg = spec[:fg] || spec["fg"]
      bg = spec[:bg] || spec["bg"]

      if fg_rgb
        codes.push(38, 2, *fg_rgb)
      elsif !default_color?(fg)
        codes.concat(color_codes(fg, foreground: true))
      end

      if bg_rgb
        codes.push(48, 2, *bg_rgb)
      elsif !default_color?(bg)
        codes.concat(color_codes(bg, foreground: false))
      end

      codes
    end

    def default_color?(color)
      color.nil? || color.to_i == Fatty::Color::DEFAULT_INDEX
    end

    def color_codes(color, foreground:)
      color = color.to_i

      if foreground
        if color.between?(0, 7)
          [30 + color]
        elsif color.between?(8, 15)
          [90 + color - 8]
        else
          [38, 5, color]
        end
      elsif color.between?(0, 7)
        [40 + color]
      elsif color.between?(8, 15)
        [100 + color - 8]
      else
        [48, 5, color]
      end
    end

    def rouge_theme
      case markdown_code_theme
      when :solarized_light
        Rouge::Themes::Base16::Solarized.mode(:light).new
      when :solarized_dark
        Rouge::Themes::Base16::Solarized.mode(:dark).new
      when :base16
        Rouge::Themes::Base16.new
      when :base16_monokai
        Rouge::Themes::Base16::Monokai.mode(:dark).new
      when :monokai
        Rouge::Themes::Monokai.new
      when :monokai_sublime
        Rouge::Themes::MonokaiSublime.new
      when :gruvbox_light
        Rouge::Themes::Gruvbox.mode(:light).new
      when :gruvbox_dark
        Rouge::Themes::Gruvbox.mode(:dark).new
      when :github
        Rouge::Themes::Github.mode(:light).new
      when :github_dark
        Rouge::Themes::Github.mode(:dark).new
      when :molokai
        Rouge::Themes::Molokai.new
      when :colorful
        Rouge::Themes::Colorful.new
      when :bw
        Rouge::Themes::BlackWhiteTheme.new
      when :pastie
        Rouge::Themes::Pastie.new
      when :tulip
        Rouge::Themes::Tulip.new
      when :igor_pro
        Rouge::Themes::IgorPro.new
      when :magritte
        Rouge::Themes::Magritte.new
      else
        Rouge::Themes::ThankfulEyes.new
      end
    end

    def markdown_code_theme
      value = @theme[:markdown_code_theme] if @theme.respond_to?(:[])
      value.to_s.tr("-", "_").to_sym
    end

    def rouge_formatter
      formatter_class = truecolor? ? Rouge::Formatters::TerminalTruecolor : Rouge::Formatters::Terminal256
      formatter_class.new(rouge_theme)
    end

    def truecolor?
      @truecolor
    end
  end
end
