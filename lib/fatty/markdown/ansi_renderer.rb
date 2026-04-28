# frozen_string_literal: true

require "rouge"
require "cgi"

module Fatty
  class AnsiRenderer < Redcarpet::Render::Base
    def initialize(width: 80)
      super()
      @width = width.to_i
    end

    def block_code(code, language)
      lexer = rouge_lexer(language.to_s, code.to_s)
      formatter = Rouge::Formatters::Terminal256.new
      gutter = Rainbow("│ ").faint.to_s

      highlighted = formatter.format(lexer.lex(code.to_s))
      lines = highlighted.lines.map(&:chomp)

      lines.pop while lines.any? && Fatty::Ansi.plain_text(lines.last).strip.empty?

      body = lines.map do |line|
        "#{gutter}#{line}"
      end.join("\n")

      "#{body}\n\n"
    end

    def codespan(code)
      Rainbow(code.to_s).cyan.bright.to_s
    end

    def normal_text(text)
      CGI.unescapeHTML(text.to_s)
    end

    def normal_text(text)
      render_inline_html(CGI.unescapeHTML(text.to_s))
    end

    def double_emphasis(text)
      Rainbow(text).bright.to_s
    end

    # def underline(text)
    #   Rainbow(text).underline.to_s
    # end

    def raw_html(html)
      render_inline_html(CGI.unescapeHTML(html.to_s))
    end

    def render_inline_html(text)
      text.to_s.gsub(%r{<span\s+class=["']underline["']>(.*?)</span>}m) do
        Rainbow(Regexp.last_match(1)).underline.to_s
      end
    end

    # Curses does not reliably render true italics, so we use underline instead.
    def emphasis(text)
      Rainbow(text).underline.to_s
    end

    # Curses does not support strike-through, but this emulates it with
    # unicode "combining characters" by adding a "Long Stroke Overlay"
    # (U+0366) after each character, which overlays each with a strike-through
    # overlay.  We just had to make sure that Ansi.visible_length takes these
    # into account in computing width.
    def strikethrough(text)
      text.to_s.each_char.map { |ch| "#{ch}\u0336" }.join
    end

    def highlight(text)
      Rainbow(text).background(:yellow).black.to_s
    end

    def link(link, _title, content)
      label = content.to_s.empty? ? link : content
      "#{Rainbow(label).underline} #{Rainbow("<#{link}>").bright}"
    end

    def autolink(link, _link_type)
      Rainbow(link).underline.to_s
    end

    def quote(text)
      "“#{text}”"
    end

    def block_quote(quote)
      gutter = Rainbow("│ ").bright.to_s
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
      text.to_s.lines.map do |line|
        if line.strip.empty?
          line
        else
          "#{prefix}#{line}"
        end
      end.join
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
        text = th(text) if header
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

    def th(text)
      Rainbow(text).green.bold
    end

    def h1(text)
      Rainbow(text.to_s).cyan.bright
    end

    def h2(text)
      Rainbow(text.to_s).yellow.bright
    end

    def h3(text)
      Rainbow(text.to_s).magenta.underline
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

    def wrap(text, first_prefix: "", rest_prefix: first_prefix)
      width = @width.to_i.clamp(20, 80)

      words = text.to_s.split(/\s+/)
      lines = []
      line = +""

      words.each do |word|
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

      lines.join("\n")
    end
  end
end
