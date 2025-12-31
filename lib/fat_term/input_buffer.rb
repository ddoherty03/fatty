# frozen_string_literal: true

require "unicode/display_width"

module FatTerm
  class InputBuffer
    attr_accessor :text, :cursor

    def initialize
      @text = +""
      @cursor = 0
    end

    def insert(str)
      text.insert(@cursor, str)
      @cursor += str.length
    end

    def delete_char_backward
      return if @cursor.zero?

      text.slice!(@cursor - 1)
      @cursor -= 1
    end

    def move_left
      @cursor -= 1 if @cursor.positive?
    end

    def move_right
      @cursor += 1 if @cursor < text.length
    end

    def clear
      text.clear
      @cursor = 0
    end

    def display_width
      Unicode::DisplayWidth.of(text)
    end
  end
end
