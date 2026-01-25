# frozen_string_literal: true

require "unicode/display_width"

module FatTerm
  # The InputBuffer class maintains an editable line of input together with a
  # cursor position.  It is responsible only for text editing semantics —
  # inserting and deleting characters, moving the cursor, and reporting the
  # current contents of the buffer.
  #
  # InputBuffer has no knowledge of keybindings, terminal I/O, history, or
  # rendering.  Higher-level components (such as InputField and Terminal)
  # translate user actions into editing operations on the buffer.
  #
  # The buffer is conceptually a single line of text.  Newlines are not
  # interpreted specially and are treated as ordinary characters if present.
  #
  # Responsibilities:
  #   - Maintain the current text and cursor position
  #   - Insert text at the cursor
  #   - Delete characters before or after the cursor
  #   - Move the cursor within valid bounds
  #   - Replace or clear the buffer contents
  #
  # Non-responsibilities:
  #   - Keyboard decoding or modifier interpretation
  #   - Command history navigation
  #   - Screen layout or cursor rendering
  #   - Validation of user input
  #
  # The cursor position represents a location *between* characters.  It is
  # always an integer between 0 and text.length, inclusive.  All editing
  # operations must preserve this invariant.
  class InputBuffer
    include Actionable

    attr_accessor :text, :cursor, :word_re

    DEFAULT_WORD_CHARS = "[[:alnum:]_]"

    def initialize(word_chars: DEFAULT_WORD_CHARS, word_re: nil)
      @text = +""
      @cursor = 0
      @word_re =
        if word_re
          word_re
        else
          # word_chars is a fragment like "[[:alnum:]_]" or "[[:alnum:]_-]"
          Regexp.new(word_chars)
        end
    end

    # :category: Queries

    def empty?
      text.empty?
    end

    def length
      @text.length
    end

    def bol?
      @cursor.zero?
    end

    def eol?
      @cursor == @text.length
    end

    def text_before_cursor
      text[0, @cursor] || ""
    end

    def text_after_cursor
      text[@cursor..] || ""
    end

    # category: Actions: Cursor Movement

    desc "Move cursor to the beginning of the line"
    action :bol do
      @cursor = 0
    end

    desc "Move cursor to the end of the line"
    action :eol do
      @cursor = text.length
    end

    desc "Move cursor one word to the right"
    action :move_word_right do
      chars = text.chars
      i = @cursor
      # skip non-word
      i += 1 while i < chars.length && !word_char?(chars[i])
      # skip word
      i += 1 while i < chars.length && word_char?(chars[i])
      @cursor = i
    end

    desc "Move cursor one word to the left"
    action :move_word_left do
      chars = text.chars
      i = @cursor

      # skip non-word chars to the left
      i -= 1 while i > 0 && !word_char?(chars[i - 1])

      # skip word chars to the left
      i -= 1 while i > 0 && word_char?(chars[i - 1])

      @cursor = i
    end

    desc "Move cursor one character to the left"
    action :move_left do
      @cursor -= 1 if @cursor.positive?
    end

    desc "Move cursor one character to the right"
    action :move_right do
      @cursor += 1 if @cursor < text.length
    end

    # :category: Actions: Change Buffer

    desc "Clear the buffer"
    action :clear do
      text.clear
      @cursor = 0
    end

    desc "Add a string at the cursor and move cursor after the inserted text"
    action :insert do |str|
      text.insert(@cursor, str)
      @cursor += str.length
    end

    desc "Replace buffer contents with a string and move the cursor to the end"
    action :replace do |str|
      @text   = str.dup
      @cursor = @text.length
    end

    action :set, to: :replace

    desc "Delete the character before the cursor"
    action :delete_char_backward do
      return if @cursor.zero?

      text.slice!(@cursor - 1)
      @cursor -= 1
    end

    desc "Delete the character after the cursor"
    action :delete_char_forward do
      return if @cursor == text.length

      text.slice!(@cursor, 1)
    end

    desc "Delete to the end of the buffer and return deleted string"
    action :kill_to_eol do
      return "" if eol?

      deleted = text[@cursor..] || ""
      text.slice!(@cursor..)
      deleted
    end

    desc "Delete to the beginning of the buffer and return deleted string"
    action :kill_to_bol do
      return "" if bol?

      deleted = text[0, @cursor] || ""
      text.slice!(0, @cursor)
      @cursor = 0
      deleted
    end

    desc "Delete word after the cursor and return the deleted string"
    action :kill_word_forward do
      return "" if eol?

      start = @cursor
      move_word_right
      finish = @cursor
      deleted = text[start, finish - start] || ""
      text.slice!(start, finish - start)
      @cursor = start
      deleted
    end

    desc "Delete word before the cursor and return the deleted string"
    action :kill_word_backward do
      return "" if bol?

      finish = @cursor
      move_word_left
      start = @cursor
      deleted = text[start, finish - start] || ""
      text.slice!(start, finish - start)
      @cursor = start
      deleted
    end

    # :category: Utilities

    def display_width
      Unicode::DisplayWidth.of(text)
    end

    private

    def word_char?(ch)
      @word_re.match?(ch)
    end
  end
end
