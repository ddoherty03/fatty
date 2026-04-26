# frozen_string_literal: true

module Fatty
  RSpec.describe InputBuffer do
    let(:b) { InputBuffer.new }
    let(:bw) { InputBuffer.new(word_chars: "[[:alnum:]_-]") }

    it "starts empty with cursor at 0" do
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)
      expect(b.empty?).to be(true)
    end

    it "represents itself with #to_s method no mark" do
      b.insert("abcd efgh ijkl mnop qrst uv wxyz")
      b.move_word_left
      expect(b.to_s).to match(/\|wxyz/)
      expect(b.inspect).to match(/\|wxyz/)
      b.bol
      expect(b.to_s).to match(/\|abcd /)
      expect(b.inspect).to match(/\|abcd /)
      b.eol
      expect(b.to_s).to match(/wxyz\|/)
      expect(b.inspect).to match(/wxyz\|/)
    end

    it "represents itself with #to_s method with mark" do
      b.insert("abcd efgh ijkl mnop qrst uv wxyz")
      b.bol
      b.move_word_right
      b.set_mark
      b.move_word_right
      b.move_word_right
      expect(b.to_s).to match(/abcd\[ efgh ijkl\]\|/)
      expect(b.inspect).to match(/abcd\[ efgh ijkl\]\|/)
    end

    it "inserts at cursor and advances cursor" do
      b.insert("a")
      b.insert("b")
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)
    end

    it "inserts in the middle (cursor-aware)" do
      b.insert("a")
      b.insert("c")
      b.move_left
      b.insert("b")
      expect(b.text).to eq("abc")
      expect(b.cursor).to eq(2)
    end

    it "move_left and move_right clamp to bounds" do
      b.insert("ab")
      10.times { b.move_left }
      expect(b.cursor).to eq(0)
      10.times { b.move_right }
      expect(b.cursor).to eq(2)
    end

    it "delete_backward deletes char left of cursor" do
      b.insert("abc")
      b.delete_char_backward
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)
    end

    it "delete_backward at beginning is a no-op" do
      b.insert("a")
      b.move_left
      expect { b.delete_char_backward }.not_to raise_error
      expect(b.text).to eq("a")
      expect(b.cursor).to eq(0)
    end

    it "delete_forward deletes char at cursor" do
      b.insert("abc")
      b.move_left # cursor at 2
      b.move_left # cursor at 1
      b.delete_char_forward
      expect(b.text).to eq("ac")
      expect(b.cursor).to eq(1)
    end

    it "delete_forward at end is a no-op" do
      b.insert("a")
      expect { b.delete_char_forward }.not_to raise_error
      expect(b.text).to eq("a")
      expect(b.cursor).to eq(1)
    end

    it "bol/eol move to beginning/end" do
      b.insert("abc")
      b.bol
      expect(b.cursor).to eq(0)
      b.eol
      expect(b.cursor).to eq(3)
    end

    it "#replace replaces text and moves cursor to end" do
      b.insert("abc")
      b.replace("Easy as xyz")
      expect(b.text).to eq("Easy as xyz")
      expect(b.cursor).to eq(11)
    end

    it "clear empties text and resets cursor" do
      b.insert("abc")
      b.clear
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)
    end

    it "display_width returns the unicode display width" do
      b.insert("a")
      expect(b.display_width).to be >= 1
    end

    it "moves by words using configurable word_chars" do
      bw.replace("foo-bar baz")
      bw.bol
      bw.move_word_right
      expect(bw.cursor).to eq("foo-bar".length) # 7
      bw.move_word_right
      expect(bw.cursor).to eq("foo-bar baz".length)
    end

    it "reports length" do
      expect(b.length).to eq(0)
      b.insert("abc")
      expect(b.length).to eq(3)
    end

    it "bol?/eol? reflect cursor position" do
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
      b.set("xyz")
      expect(b.text).to eq("xyz")
      expect(b.cursor).to eq(3)
    end

    it "kill_to_eol deletes from cursor to end and returns deleted text" do
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
      bw.replace("foo-bar baz")
      bw.eol
      bw.move_word_left
      expect(bw.cursor).to eq("foo-bar ".length) # 8, cursor before 'b' in baz
      bw.move_word_left
      expect(bw.cursor).to eq(0)
    end

    it "kill_word_forward deletes to end of next word and returns deleted text" do
      bw.replace("foo-bar baz")
      bw.bol
      expect(bw.kill_word_forward).to eq("foo-bar")
      expect(bw.text).to eq(" baz")
      expect(bw.cursor).to eq(0)
    end

    it "kill_word_backward deletes to beginning of previous word and returns deleted text" do
      bw.replace("foo-bar baz")
      bw.eol
      expect(bw.kill_word_backward).to eq("baz")
      expect(bw.text).to eq("foo-bar ")
      expect(bw.cursor).to eq("foo-bar ".length)
    end

    it "never lets cursor go out of bounds" do
      b.replace("a")
      b.bol
      10.times { b.move_left }
      expect(b.cursor).to eq(0)
      b.eol
      10.times { b.move_right }
      expect(b.cursor).to eq(1)
    end

    it "supports supplying a custom word_re directly" do
      buf = InputBuffer.new(word_re: /[[:alpha:]]/)
      buf.replace("aaBB cc")
      buf.bol

      buf.move_word_right
      expect(buf.cursor).to eq(4) # aaBB

      buf.move_word_right
      expect(buf.cursor).to eq(7) # cc
    end

    it "handles word_re that matches nothing" do
      buf = InputBuffer.new(word_re: /$a/) # never matches
      buf.replace("abc def")
      buf.bol
      buf.move_word_right
      expect(buf.cursor).to eq("abc def".length) # skips all as non-word
    end

    it "move_word_right can be repeated and clamps at end of text" do
      bw.replace("foo--bar   baz")
      bw.bol

      bw.move_word_right
      expect(bw.cursor).to eq("foo--bar".length) # 8

      bw.move_word_right
      expect(bw.cursor).to eq("foo--bar   baz".length) # 14

      10.times { bw.move_word_right }
      expect(bw.cursor).to eq("foo--bar   baz".length) # stays clamped
    end

    it "move_word_left can be repeated and clamps at beginning of text" do
      bw.replace("foo--bar   baz")
      bw.eol

      bw.move_word_left
      expect(bw.cursor).to eq("foo--bar   ".length) # 11 (start of 'baz')

      bw.move_word_left
      expect(bw.cursor).to eq(0) # start of 'foo--bar'

      10.times { bw.move_word_left }
      expect(bw.cursor).to eq(0) # stays clamped
    end

    it "handles multibyte characters (codepoint-based cursor and deletion)" do
      # Greek lambda (multibyte)
      b.insert("λ")
      # precomposed e-acute
      b.insert("é")
      # CJK (typically width 2)
      b.insert("中")

      expect(b.text).to eq("λé中")
      expect(b.cursor).to eq(3)

      b.move_left
      expect(b.cursor).to eq(2)

      b.delete_char_backward
      # removed 'é'
      expect(b.text).to eq("λ中")
      expect(b.cursor).to eq(1)

      expect(b.display_width).to be >= 3
    end

    it "treats combining sequences as multiple codepoints (not grapheme-aware yet)" do
      s = "e\u0301" # e + combining acute accent
      b.insert(s)

      expect(b.text).to eq(s)
      expect(b.cursor).to eq(2) # two codepoints

      b.delete_char_backward
      expect(b.text).to eq("e") # removed only the combining mark
      expect(b.cursor).to eq(1)
    end

    it "undo/redo restores text and cursor for insert" do
      b.insert("ab")
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)

      expect(b.undo).to be_truthy
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)

      expect(b.redo).to be_truthy
      expect(b.text).to eq("ab")
      expect(b.cursor).to eq(2)
    end

    it "redo stack is cleared by a new edit after undo" do
      b.insert("ab")
      b.undo
      expect(b.can_redo?).to be(true)

      b.insert("x")
      expect(b.can_redo?).to be(false)
    end

    it "cursor motion does not create undo points" do
      b.insert("ab")
      b.move_left
      b.move_left
      expect(b.cursor).to eq(0)

      # undo should undo the insert, not the motion
      b.undo
      expect(b.text).to eq("")
      expect(b.cursor).to eq(0)
    end

    it "move_word_right repeats and clamps" do
      bw.replace("foo--bar   baz")
      bw.bol
      bw.move_word_right(count: 2)
      expect(bw.cursor).to eq("foo--bar   baz".length)
    end

    it "delete_char_forward supports count and is one undo step" do
      b.replace("abcdef")
      b.bol
      b.delete_char_forward(count: 3)
      expect(b.text).to eq("def")
      expect(b.undo).to be_truthy
      expect(b.text).to eq("abcdef")
    end

    it "kill_word_forward supports count and returns concatenated deleted text" do
      bw.replace("foo--bar baz")
      bw.bol
      deleted = bw.kill_word_forward(count: 2)
      expect(deleted).to eq("foo--bar baz")
      expect(bw.text).to eq("")
    end

    it "replace_span replaces a slice and sets cursor" do
      b.replace("hello world")
      b.replace_span(6, 5, "dan")
      expect(b.text).to eq("hello dan")
      expect(b.cursor).to eq("hello ".length + "dan".length)
    end

    it "replace_range accepts a range" do
      b.replace("abcDEFghi")
      b.replace_range(3...6, "xxx")
      expect(b.text).to eq("abcxxxghi")
    end

    it "delete_range deletes range and returns deleted text" do
      b.replace("abcdef")
      b.delete_range(2...5)
      expect(b.text).to eq("abf")
      expect(b.cursor).to eq(2)
    end

    it "delete_range on empty range returns '' and does not create an undo step" do
      b.replace("abc")
      # undo stack size doesn't change after deleting empty range
      sz_b4_del = b.undo_size
      expect(b.delete_range(1...1)).to eq("")
      sz_aft_del = b.undo_size
      expect(sz_b4_del).to eq(sz_aft_del)
    end

    it "handles inclusive and exclusive ranges correctly" do
      b.replace("abcdef")

      # exclusive range: delete cde
      deleted = b.delete_range(2...5)
      expect(deleted).to eq("cde")
      expect(b.text).to eq("abf")
      expect(b.cursor).to eq(2)

      # reset
      b.replace("abcdef")

      # inclusive range: delete cde (2..4)
      deleted = b.delete_range(2..4)
      expect(deleted).to eq("cde")
      expect(b.text).to eq("abf")
      expect(b.cursor).to eq(2)
    end

    describe "kill ring and yanking" do
      it "supports mark + region_range" do
        b.replace("abcdef")
        b.bol
        b.set_mark
        b.move_right(count: 3)

        r = b.region_range
        expect(r).to eq(0...3)
      end

      it "kill_region deletes region, clears mark, and yanks it back" do
        b.replace("abcdef")
        b.bol
        b.set_mark
        b.move_right(count: 3)

        expect(b.kill_region).to eq("abc")
        expect(b.text).to eq("def")
        expect(b.cursor).to eq(0)
        expect(b.region_active?).to be(false)

        expect(b.yank).to eq("abc")
        expect(b.text).to eq("abcdef")
        expect(b.cursor).to eq(3)
      end

      it "copy_region does not delete but is yankable" do
        b.replace("abcdef")
        b.bol
        b.set_mark
        b.move_right(count: 2)

        expect(b.copy_region).to eq("ab")
        expect(b.text).to eq("abcdef")
        b.eol
        expect(b.yank).to eq("ab")
        expect(b.text).to eq("abcdefab")
      end

      it "replace_region replaces active region and clears mark" do
        b.replace("abcdef")
        b.bol
        b.set_mark
        b.move_right(count: 3)

        expect(b.region_active?).to be(true)
        b.replace_region("Z")

        expect(b.text).to eq("Zdef")
        expect(b.cursor).to eq(1)
        expect(b.region_active?).to be(false)

        b.replace_region("Q")
        expect(b.text).to eq("ZQdef")
      end

      it "yank_pop cycles the kill ring by replacing the last yanked text" do
        b.replace("hello ")
        b.eol

        b.insert("X")
        b.kill_word_backward # kills "X"
        b.insert("Y")
        b.kill_word_backward # kills "Y" (now most recent)

        expect(b.yank).to eq("Y")
        expect(b.text).to eq("hello Y")

        expect(b.yank_pop).to eq("X")
        expect(b.text).to eq("hello X")
      end
    end

    describe "#transpose_chars" do
      it "swaps the character before point with the character at point" do
        b.replace("abcd")
        b.cursor = 2

        b.transpose_chars

        expect(b.text).to eq("acbd")
        expect(b.cursor).to eq(3)
      end

      it "swaps the last two characters when point is at end of line" do
        b.replace("abcd")
        b.cursor = 4

        b.transpose_chars

        expect(b.text).to eq("abdc")
        expect(b.cursor).to eq(4)
      end

      it "does nothing at beginning of line" do
        b.replace("abcd")
        b.cursor = 0

        b.transpose_chars

        expect(b.text).to eq("abcd")
        expect(b.cursor).to eq(0)
      end

      it "does not operate on virtual suffix text" do
        b.text = +"ab"
        b.cursor = 2
        b.virtual_suffix = +"cd"

        b.transpose_chars

        expect(b.text).to eq("ba")
        expect(b.virtual_suffix).to eq("cd")
        expect(b.cursor).to eq(2)
      end
    end

    describe "#transpose_words" do
      it "swaps the previous and next words when point is between them" do
        b.replace("alpha beta")
        b.cursor = 5

        b.transpose_words

        expect(b.text).to eq("beta alpha")
        expect(b.cursor).to eq("beta alpha".length)
      end

      it "swaps the word at point with the following word" do
        b.replace("alpha beta gamma")
        b.cursor = 7

        b.transpose_words

        expect(b.text).to eq("alpha gamma beta")
        expect(b.cursor).to eq("alpha gamma beta".length)
      end

      it "swaps the previous word with the word at point when there is no following word" do
        b.replace("alpha beta")
        b.cursor = 8

        b.transpose_words

        expect(b.text).to eq("beta alpha")
        expect(b.cursor).to eq("beta alpha".length)
      end

      it "preserves intervening punctuation and spacing" do
        b.replace("alpha,   beta")
        b.cursor = 6

        b.transpose_words

        expect(b.text).to eq("beta,   alpha")
      end

      it "uses the configured word definition" do
        bw.replace("foo-bar baz")
        bw.cursor = "foo-bar".length

        bw.transpose_words

        expect(bw.text).to eq("baz foo-bar")
      end
    end
  end
end
