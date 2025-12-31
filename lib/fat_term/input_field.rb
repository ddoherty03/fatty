# frozen_string_literal: true

module FatTerm
  class InputField
    attr_reader :buffer, :prompt

    def initialize(prompt:, buffer: InputBuffer.new)
      @prompt = prompt
      @buffer = buffer
    end

    def act_on(action)
      return unless action

      send(action)
    end

    # Visual cursor X position in the window
    def cursor_x
      prompt_width + @buffer.cursor
    end

    def prompt_text
      @prompt.text
    end

    def prompt_width
      # keep it simple for now; upgrade to Unicode::DisplayWidth later
      prompt_text.length
    end

    # Editor actions (prompt-safe)
    def backward_char
      @buffer.move_left if @buffer.cursor.positive?
    end

    def forward_char
      @buffer.move_right
    end

    def forward_word
      text = @buffer.text
      i = @buffer.cursor

      i += 1 while i < text.length && text[i] =~ /\w/
      i += 1 while i < text.length && text[i] =~ /\W/

      @buffer.cursor = i
    end

    def backward_word
      text = @buffer.text
      i = @buffer.cursor - 1
      return if i < 0

      i -= 1 while i >= 0 && text[i] =~ /\W/
      i -= 1 while i >= 0 && text[i] =~ /\w/

      @buffer.cursor = i + 1
    end

    def delete_char_forward
      return if @buffer.cursor >= @buffer.text.length

      @buffer.text.slice!(@buffer.cursor)
    end

    def delete_char_backward
      @buffer.delete_char_backward
    end

    def kill_to_eol
      return if @buffer.cursor >= @buffer.text.length

      @buffer.text.slice!(@buffer.cursor..)
    end

    def insert(str)
      @buffer.insert(str)
    end

    def accept_line
      line = @buffer.text.dup
      @buffer.clear
      line
    end

    def bol
      @buffer.cursor = 0
    end

    def eol
      @buffer.cursor = @buffer.text.length
    end

    def delete_word_backward
      return if @buffer.cursor.zero?

      i = @buffer.cursor - 1
      i -= 1 while i.positive? && @buffer.text[i] =~ /\s/
      i -= 1 while i.positive? && @buffer.text[i] =~ /\w/

      start = i.zero? ? 0 : i + 1
      @buffer.text.slice!(start...@buffer.cursor)
      @buffer.cursor = start
    end

    def delete_word_forward
      return if @buffer.cursor >= @buffer.text.length

      i = @buffer.cursor
      i += 1 while i < @buffer.text.length && @buffer.text[i] =~ /\s/
      i += 1 while i < @buffer.text.length && @buffer.text[i] =~ /\w/

      @buffer.text.slice!(@buffer.cursor...i)
    end

  end
end
