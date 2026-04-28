# frozen_string_literal: true

require "rouge"

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
      formatter.format(lexer.lex(code.to_s)).rstrip.lines.map do |line|
        "#{gutter}#{line}"
      end.join + "\n\n"
    end

    def codespan(code)
      Rainbow(code.to_s).cyan.bright.to_s
    end

    def normal_text(text)
      text
    end

    def double_emphasis(text)
      Rainbow(text).bright.to_s
    end

    def underline(text)
      Rainbow(text).underline.to_s
    end

    def emphasis(text)
      Rainbow(text).italic.to_s
      # Rainbow(text).underline.to_s
    rescue StandardError
      Rainbow(text).underline.to_s
    end

    def strikethrough(text)
      Rainbow(text).strike.to_s
    rescue StandardError
      "~#{text}~"
    end

    def strikethrough(text)
      Rainbow("~#{text}~").faint.to_s
    end

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
      quote.lines.map { |line| Rainbow("│ ").bright.to_s + line }.join + "\n"
    end

    def header(text, level)
      case level
      when 1 then "\e[1;36m#{text}\e[0m\n\n"
      when 2 then "\e[1;33m#{text}\e[0m\n"
      else "\e[1m#{text}\e[0m\n"
      end
    end

    def paragraph(text)
      "#{wrap(text)}\n\n"
    end

    def list(contents, _type)
      "#{contents}\n"
    end

    def list_item(text, _type)
      wrap(
        text.strip,
        first_prefix: "  • ",
        rest_prefix: "    ",
      ) + "\n"
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
      Rainbow(text).cyan.bright
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
      width = [@width.to_i, 20].max

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
