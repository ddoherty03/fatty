# frozen_string_literal: true

module FatTerm
  RSpec.describe InputBuffer do
    it "starts empty with cursor at 0" do
      b = InputBuffer.new
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)
      expect(b.empty?).to be(true)
    end

    it "inserts at cursor and advances cursor" do
      b = InputBuffer.new
      b.insert("a")
      b.insert("b")
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)
    end

    it "inserts in the middle (cursor-aware)" do
      b = InputBuffer.new
      b.insert("a")
      b.insert("c")
      b.move_left
      b.insert("b")
      expect(b.text).to eq("abc")
      expect(b.cursor).to eq(2)
    end

    it "move_left and move_right clamp to bounds" do
      b = InputBuffer.new
      b.insert("ab")
      10.times { b.move_left }
      expect(b.cursor).to eq(0)
      10.times { b.move_right }
      expect(b.cursor).to eq(2)
    end

    it "delete_backward deletes char left of cursor" do
      b = InputBuffer.new
      b.insert("abc")
      b.delete_char_backward
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)
    end

    it "delete_backward at beginning is a no-op" do
      b = InputBuffer.new
      b.insert("a")
      b.move_left
      expect { b.delete_char_backward }.not_to raise_error
      expect(b.text).to eq("a")
      expect(b.cursor).to eq(0)
    end

    it "delete_forward deletes char at cursor" do
      b = InputBuffer.new
      b.insert("abc")
      b.move_left # cursor at 2
      b.move_left # cursor at 1
      b.delete_char_forward
      expect(b.text).to eq("ac")
      expect(b.cursor).to eq(1)
    end

    it "delete_forward at end is a no-op" do
      b = InputBuffer.new
      b.insert("a")
      expect { b.delete_char_forward }.not_to raise_error
      expect(b.text).to eq("a")
      expect(b.cursor).to eq(1)
    end

    it "bol/eol move to beginning/end" do
      b = InputBuffer.new
      b.insert("abc")
      b.bol
      expect(b.cursor).to eq(0)
      b.eol
      expect(b.cursor).to eq(3)
    end

    it "#replace replaces text and moves cursor to end" do
      b = InputBuffer.new
      b.insert("abc")
      b.replace("Easy as xyz")
      expect(b.text).to eq("Easy as xyz")
      expect(b.cursor).to eq(11)
    end

    it "clear empties text and resets cursor" do
      b = InputBuffer.new
      b.insert("abc")
      b.clear
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)
    end

    it "display_width returns the unicode display width" do
      b = InputBuffer.new
      b.insert("a")
      expect(b.display_width).to be >= 1
    end

    it "moves by words using configurable word_chars" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo-bar baz")
      b.bol
      b.move_word_right
      expect(b.cursor).to eq("foo-bar".length) # 7
      b.move_word_right
      expect(b.cursor).to eq("foo-bar baz".length)
    end

    it "reports length" do
      b = InputBuffer.new
      expect(b.length).to eq(0)
      b.insert("abc")
      expect(b.length).to eq(3)
    end

    it "bol?/eol? reflect cursor position" do
      b = InputBuffer.new
      expect(b.bol?).to be(true)
      expect(b.eol?).to be(true)

      b.insert("abc")
      expect(b.bol?).to be(false)
      expect(b.eol?).to be(true)

      b.move_left
      expect(b.bol?).to be(false)
      expect(b.eol?).to be(false)

      b.bol
      expect(b.bol?).to be(true)
      expect(b.eol?).to be(false)
    end

    it "text_before_cursor / text_after_cursor split at cursor" do
      b = InputBuffer.new
      b.replace("abc")
      b.bol
      expect(b.text_before_cursor).to eq("")
      expect(b.text_after_cursor).to eq("abc")

      b.move_right
      expect(b.text_before_cursor).to eq("a")
      expect(b.text_after_cursor).to eq("bc")

      b.eol
      expect(b.text_before_cursor).to eq("abc")
      expect(b.text_after_cursor).to eq("")
    end

    it "set is an alias for replace" do
      b = InputBuffer.new
      b.set("xyz")
      expect(b.text).to eq("xyz")
      expect(b.cursor).to eq(3)
    end

    it "kill_to_eol deletes from cursor to end and returns deleted text" do
      b = InputBuffer.new
      b.replace("abc def")
      b.bol
      4.times { b.move_right } # cursor after "abc "
      expect(b.kill_to_eol).to eq("def")
      expect(b.text).to eq("abc ")
      expect(b.cursor).to eq(4)

      # at eol => no-op
      expect(b.kill_to_eol).to eq("")
      expect(b.text).to eq("abc ")
    end

    it "kill_to_bol deletes from beginning to cursor and returns deleted text" do
      b = InputBuffer.new
      b.replace("abc def")
      b.bol
      4.times { b.move_right } # cursor after "abc "
      expect(b.kill_to_bol).to eq("abc ")
      expect(b.text).to eq("def")
      expect(b.cursor).to eq(0)

      # at bol => no-op
      expect(b.kill_to_bol).to eq("")
      expect(b.text).to eq("def")
      expect(b.cursor).to eq(0)
    end

    it "move_word_left mirrors move_word_right using word_chars" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo-bar baz")
      b.eol
      b.move_word_left
      expect(b.cursor).to eq("foo-bar ".length) # 8, cursor before 'b' in baz
      b.move_word_left
      expect(b.cursor).to eq(0)
    end

    it "kill_word_forward deletes to end of next word and returns deleted text" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo-bar baz")
      b.bol
      expect(b.kill_word_forward).to eq("foo-bar")
      expect(b.text).to eq(" baz")
      expect(b.cursor).to eq(0)
    end

    it "kill_word_backward deletes to beginning of previous word and returns deleted text" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo-bar baz")
      b.eol
      expect(b.kill_word_backward).to eq("baz")
      expect(b.text).to eq("foo-bar ")
      expect(b.cursor).to eq("foo-bar ".length)
    end

    it "never lets cursor go out of bounds" do
      b = InputBuffer.new
      b.replace("a")
      b.bol
      10.times { b.move_left }
      expect(b.cursor).to eq(0)
      b.eol
      10.times { b.move_right }
      expect(b.cursor).to eq(1)
    end

    it "supports supplying a custom word_re directly" do
      b = InputBuffer.new(word_re: /[[:alpha:]]/)
      b.replace("aaBB cc")
      b.bol

      b.move_word_right
      expect(b.cursor).to eq(4) # aaBB

      b.move_word_right
      expect(b.cursor).to eq(7) # cc
    end

    it "handles word_re that matches nothing" do
      b = InputBuffer.new(word_re: /$a/) # never matches
      b.replace("abc def")
      b.bol
      b.move_word_right
      expect(b.cursor).to eq("abc def".length) # skips all as non-word
    end

    it "move_word_right can be repeated and clamps at end of text" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo--bar   baz")
      b.bol

      b.move_word_right
      expect(b.cursor).to eq("foo--bar".length) # 8

      b.move_word_right
      expect(b.cursor).to eq("foo--bar   baz".length) # 14

      10.times { b.move_word_right }
      expect(b.cursor).to eq("foo--bar   baz".length) # stays clamped
    end

    it "move_word_left can be repeated and clamps at beginning of text" do
      b = InputBuffer.new(word_chars: "[[:alnum:]_-]")
      b.replace("foo--bar   baz")
      b.eol

      b.move_word_left
      expect(b.cursor).to eq("foo--bar   ".length) # 11 (start of 'baz')

      b.move_word_left
      expect(b.cursor).to eq(0) # start of 'foo--bar'

      10.times { b.move_word_left }
      expect(b.cursor).to eq(0) # stays clamped
    end

    it "handles multibyte characters (codepoint-based cursor and deletion)" do
      b = InputBuffer.new
      b.insert("λ")     # Greek lambda (multibyte)
      b.insert("é")     # precomposed e-acute
      b.insert("中")    # CJK (typically width 2)

      expect(b.text).to eq("λé中")
      expect(b.cursor).to eq(3)

      b.move_left
      expect(b.cursor).to eq(2)

      b.delete_char_backward
      expect(b.text).to eq("λ中")  # removed 'é'
      expect(b.cursor).to eq(1)

      expect(b.display_width).to be >= 3
    end

    it "treats combining sequences as multiple codepoints (not grapheme-aware yet)" do
      b = InputBuffer.new
      s = "e\u0301" # e + combining acute accent
      b.insert(s)

      expect(b.text).to eq(s)
      expect(b.cursor).to eq(2) # two codepoints

      b.delete_char_backward
      expect(b.text).to eq("e") # removed only the combining mark
      expect(b.cursor).to eq(1)
    end
  end
end
