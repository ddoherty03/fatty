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

    attr_reader :mark, :kill_ring, :undo_stack
    attr_accessor :text, :cursor, :word_re

    DEFAULT_WORD_CHARS = "[[:alnum:]_]"

    def initialize(word_chars: DEFAULT_WORD_CHARS, word_re: nil, undo_limit: 1_000, kill_ring_max: 60)
      @text = +""
      @cursor = 0
      @mark = nil
      @word_re =
        if word_re
          word_re
        else
          # word_chars is a fragment like "[[:alnum:]_]" or "[[:alnum:]_-]"
          Regexp.new(word_chars)
        end
      @undo_limit = undo_limit
      @undo_stack = []
      @redo_stack = []
      @undo_chain = nil

      @kill_ring = []
      @kill_ring_max = kill_ring_max
      @last_yank_len = 0
      @last_action = nil
    end

    # :category: Inspect

    def to_s
      text_w_cursor =
        if mark
          if mark < cursor
            "#{text[0..mark - 1]}[#{text[mark..cursor - 1]}]|#{text[cursor..]}"
          elsif mark > cursor
            "#{text[0..cursor - 1]}[|#{text[cursor..mark - 1]}]#{text[mark..]}"
          else
            # They're equal, ignore mark
            "#{text[0..cursor - 1]}|#{text[cursor..]}]"
          end
        elsif cursor > 0
          "#{text[0..cursor - 1]}|#{text[cursor..]}"
        else
          "|#{text}"
        end
      "<InputBuffer:#{object_id}> <#{text_w_cursor}> => Kill[#{kill_ring.size}] => Undo[#{undo_stack.size}]"
    end
    alias_method :inspect, :to_s

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

    def can_undo?
      !@undo_stack.empty?
    end

    def can_redo?
      !@redo_stack.empty?
    end

    def undo_size
      @undo_stack.size
    end

    def region_active?
      !!@mark && @mark != @cursor
    end

    def region_range
      if region_active?
        a = @mark
        b = @cursor
        s = [a, b].min
        e = [a, b].max
        clamp_range(s...e)
      end
    end

    # Return whether the action with name takes a count: parameter.
    def countable?(name)
      return false unless respond_to?(name)

      params = method(name).parameters
      params.any? { |kind, key| kind == :key && key == :count } ||
        params.any? { |kind, key| kind == :keyreq && key == :count }
    rescue NameError
      false
    end

    # category: Actions: Cursor Movement

    desc "Undo the most recent buffer edit, text and cursor. Returns true/false."
    action :undo do
      undo
    end

    desc "Redo the most recently undone edit. Returns true/false."
    action :redo do
      redo
    end

    # category: Actions: Cursor Movement

    desc "Move cursor to the beginning of the line"
    action :bol do
      break_undo_chain!
      @cursor = 0
    end

    desc "Move cursor to the end of the line"
    action :eol do
      break_undo_chain!
      @cursor = text.length
    end

    def move_word_right_once
      break_undo_chain!
      chars = text.chars
      i = @cursor
      # skip non-word
      i += 1 while i < chars.length && !word_char?(chars[i])
      # skip word
      i += 1 while i < chars.length && word_char?(chars[i])
      @cursor = i
    end
    private :move_word_right_once

    desc "Move cursor count words to the right"
    action :move_word_right do |count: 1|
      break_undo_chain!
      repeat(count) { move_word_right_once }
    end

    def move_word_left_once
      break_undo_chain!
      chars = text.chars
      i = @cursor
      # skip non-word chars to the left
      i -= 1 while i > 0 && !word_char?(chars[i - 1])
      # skip word chars to the left
      i -= 1 while i > 0 && word_char?(chars[i - 1])
      @cursor = i
    end
    private :move_word_left_once

    desc "Move cursor count words to the left"
    action :move_word_left do |count: 1|
      break_undo_chain!
      repeat(count) { move_word_left_once }
    end

    desc "Move cursor count characters to the left"
    action :move_left do |count: 1|
      break_undo_chain!
      n = normalize_count(count)
      @cursor = [@cursor - n, 0].max
    end

    desc "Move cursor count characters to the right"
    action :move_right do |count: 1|
      break_undo_chain!
      n = normalize_count(count)
      @cursor = [@cursor + n, text.length].min
    end

    # :category: Actions: Region

    desc "Set the mark at the current cursor position (activates region)."
    action :set_mark do
      break_undo_chain!
      @mark = @cursor
    end

    desc "Clear the mark (deactivates region)."
    action :clear_mark do
      break_undo_chain!
      @mark = nil
    end

    # :category: Actions: Change Buffer

    desc "Clear the buffer"
    action :clear do
      return if text.empty? && @cursor.zero?

      with_undo do
        @mark = nil
        @last_action = nil
        text.clear
        @cursor = 0
      end
    end

    desc "Add a count copies of string at the cursor and move cursor after the inserted text"
    action :insert do |str, count: 1|
      s = str.to_s
      n = normalize_count(count)
      return if s.empty?

      with_undo_coalesced(:insert) do
        @last_action = nil
        payload = (s * n)

        if region_active?
          r = region_range
          if r && r.begin < r.end
            # Replace the selected text
            text[r] = payload
            @cursor = r.begin + payload.length
          else
            text.insert(@cursor, payload)
            @cursor += payload.length
          end
          clear_mark
        else
          text.insert(@cursor, payload)
          @cursor += payload.length
        end
      end
    end
    action :self_insert, to: :insert

    desc "Replace buffer contents with a string and move the cursor to the end"
    action :replace do |str|
      str = str.to_s
      with_undo do
        @last_action = nil
        @text = str.dup
        @cursor = @text.length
      end
    end
    action :set, to: :replace

    desc "Delete the character before the cursor"
    action :delete_char_backward do |count: 1|
      n = normalize_count(count)
      return if @cursor.zero?

      with_undo do
        @last_action = nil
        repeat(n) do
          break if @cursor.zero?

          text.slice!(@cursor - 1)
          @cursor -= 1
        end
      end
    end

    desc "Delete count characters after the cursor"
    action :delete_char_forward do |count: 1|
      n = normalize_count(count)
      return if @cursor == text.length

      with_undo do
        @last_action = nil
        repeat(n) do
          break if @cursor == text.length

          text.slice!(@cursor, 1)
        end
      end
    end

    desc "Delete the given Range and return the deleted string"
    desc "Delete to the end of the buffer and return deleted string"
    action :kill_to_eol do
      return "" if eol?

      killed = ""
      with_undo do
        killed = delete_range(cursor...text.length)
        push_kill(killed)
        @last_action = :kill
      end
      killed
    end

    desc "Delete to the beginning of the buffer and return deleted string"
    action :kill_to_bol do
      return "" if bol?

      killed = ""
      with_undo do
        killed = delete_range(0...cursor)
        @cursor = 0
        push_kill(killed)
        @last_action = :kill
      end
      killed
    end

    desc "Kill count words after the cursor and return the deleted string"
    action :kill_word_forward do |count: 1|
      n = normalize_count(count)
      return "" if eol?

      deleted = ""
      with_undo do
        start = cursor
        finish = start
        repeat(n) do
          break if finish >= text.length

          span = word_span_forward(finish)
          break if span.begin == span.end
          finish = span.end
        end

        deleted = delete_range(start...finish)
        @cursor = start
        push_kill(deleted)
        @last_action = :kill
      end
      deleted
    end

    desc "Kill count words before the cursor and return the deleted string"
    action :kill_word_backward do |count: 1|
      n = normalize_count(count)
      return "" if bol?

      deleted = ""
      with_undo do
        finish = cursor
        start = finish
        repeat(n) do
          break if start <= 0

          span = word_span_backward(start)
          break if span.begin == span.end
          start = span.begin
        end

        deleted = delete_range(start...finish)
        @cursor = start
        push_kill(deleted)
        @last_action = :kill
      end
      deleted
    end

    desc "Kill the active region and return deleted text; pushes to kill ring."
    action :kill_region do
      r = region_range
      return "" unless r

      deleted = ""
      with_undo do
        deleted = delete_range(r)
        @cursor = r.begin
        @mark = nil
        push_kill(deleted)
        @last_action = :kill
      end
      deleted
    end

    desc "Copy the active region and return copied text; pushes to kill ring."
    action :copy_region do
      r = region_range
      return "" unless r

      break_undo_chain!
      copied = text[r] || ""
      push_kill(copied)
      @last_action = :copy
      copied
    end

    desc "Yank (paste) the most recent kill at the cursor."
    action :yank do
      y = @kill_ring.first.to_s
      return "" if y.empty?

      base = snapshot
      with_undo(before: base) do
        text.insert(@cursor, y)
        @cursor += y.length
        adjust_mark_for_replace_span!(@cursor - y.length, 0, y.length)
      end

      @yank_undo_snapshot = base
      @last_yank_len = y.length
      @last_action = :yank
      y
    end

    desc "Replace the last yanked text with the previous kill ring entry."
    action :yank_pop do |count: 1|
      return "" unless @last_action == :yank || @last_action == :yank_pop
      return "" if @kill_ring.length < 2
      return "" if @last_yank_len.to_i <= 0

      break_undo_chain!
      n = normalize_count(count)
      y = ""
      repeat(n) do
        first = @kill_ring.shift
        @kill_ring << first
        y = @kill_ring.first.to_s
      end

      start = @cursor - @last_yank_len
      start = 0 if start < 0
      replace_span(start, @last_yank_len, y)

      # We changed buffer state; redo history is no longer valid.
      @redo_stack.clear

      # Ensure the undo stack top still represents the "pre-yank" snapshot.
      if @yank_undo_snapshot
        # If the most recent undo entry isn't our yank base, replace it.
        if @undo_stack.empty? || @undo_stack.last != @yank_undo_snapshot
          @undo_stack << @yank_undo_snapshot
          @undo_stack.shift while @undo_stack.length > @undo_limit
        end
      end
      clamp_mark!
      @last_yank_len = y.length
      @last_action = :yank_pop
      y
    end

    # :category: Undo and Redo helpers

    def undo
      return if @undo_stack.empty?

      break_undo_chain!
      @redo_stack << snapshot
      restore(@undo_stack.pop)
    end

    def redo
      return if @redo_stack.empty?

      break_undo_chain!
      @undo_stack << snapshot
      restore(@redo_stack.pop)
    end

    # :category: Utilities

    def display_width
      Unicode::DisplayWidth.of(text)
    end

    # Replace a from start, length characters; move cursor to end of insertion
    def replace_span(start, length, str)
      start  = start.to_i
      length = length.to_i
      str    = str.to_s

      start = 0 if start.negative?
      start = text.length if start > text.length
      length = 0 if length.negative?

      max_len = text.length - start
      length = max_len if length > max_len

      text.slice!(start, length) if length.positive?
      text.insert(start, str) unless str.empty?
      @cursor = start + str.length
      adjust_mark_for_replace_span!(start, length, str.length)
    end

    # Replace the text in the given Range with str; move cursor to end of
    # insertion
    def replace_range(range, str)
      r = range
      raise ArgumentError, "range required" unless r.is_a?(Range)
      raise ArgumentError, "range must have begin and end" if r.begin.nil? || r.end.nil?

      start  = r.begin.to_i
      finish = r.end.to_i
      finish += 1 unless r.exclude_end?

      replace_span(start, finish - start, str)
    end

    # Replace the region with the str
    def replace_region(str)
      s = str.to_s
      r = region_range
      if r && r.begin < r.end
        replace_span(r.begin, r.end - r.begin, s)
        @mark = nil
      else
        text.insert(@cursor, s)
        @cursor += s.length
      end
      s
    end

    def delete_range(range)
      r = clamp_range(range)
      raise ArgumentError, "range required" unless r.is_a?(Range)
      raise ArgumentError, "range must have begin and end" if r.begin.nil? || r.end.nil?
      return "" if r.begin == r.end

      deleted = text[r] || ""
      replace_range(r, "")
      deleted
    end

    # Return a Range that corresponds to the whole word that is "around" the
    # cursor.  The whole region if region active, the word cursor is on a if
    # it's on a word, or nothing otherwise.
    def word_at_point_range(from = cursor)
      if region_active?
        a, b = region_range.minmax
        return a...b
      end

      chars = text.chars
      return from...from if from < 0 || from > chars.length
      return from...from if chars.empty?

      on_word =
        if from == chars.length
          from.positive? && word_char?(chars[from - 1])
        else
          word_char?(chars[from])
        end

      return from...from unless on_word

      left = from
      if left == chars.length
        left -= 1
      end
      left -= 1 while left.positive? && word_char?(chars[left - 1])

      right = from
      right += 1 while right < chars.length && word_char?(chars[right])

      left...right
    end

    # Return the Range of the buffer that a completion should replace when the
    # completion is accepted.
    def completion_replace_range(from = cursor)
      if region_active?
        r = region_range
        return r if r
      end

      prefix = completion_prefix(from)
      chars = text.chars
      at_word =
        from < chars.length && word_char?(chars[from])

      if !prefix.empty?
        if at_word
          return word_at_point_range(from)
        end

        back = word_span_backward(from)
        return back if back.begin < back.end
      end

      if at_word
        fwd = word_span_forward(from)
        return fwd.end...fwd.end
      end

      from...from
    end

    def completion_prefix(from = cursor)
      if region_active?
        r = region_range
        r ? text[r].to_s : ""
      else
        chars = text.chars
        if from.positive? && !chars.empty?
          if from < chars.length && word_char?(chars[from])
            r = word_at_point_range(from)
            r ? text[r.begin...from].to_s : ""
          elsif word_char?(chars[from - 1])
            r = word_span_backward(from)
            r ? text[r].to_s : ""
          else
            ""
          end
        else
          ""
        end
      end
    end

    private

    def with_undo(before: nil)
      break_undo_chain!
      before ||= snapshot
      yield
      after = snapshot

      if after != before
        @undo_stack << before
        @undo_stack.shift while @undo_stack.length > @undo_limit
        @redo_stack.clear
      end

      clamp_mark!
    end

    # This consolidates a number of actions of the same kind into a single
    # undo step, especially insert benefits from this since you don't want
    # each character typed to be a separate undo step.
    def with_undo_coalesced(kind)
      before = snapshot
      chain = @undo_chain
      start_new =
        chain.nil? ||
        chain[:kind] != kind ||
        chain[:cursor0] != @cursor # cursor must be where the chain expects

      if start_new
        @undo_stack << before
        @undo_stack.shift while @undo_stack.length > @undo_limit
        @redo_stack.clear
        @undo_chain = { kind: kind, cursor0: @cursor }
      end

      yield

      # update expected cursor for continued typing
      @undo_chain[:cursor0] = @cursor if @undo_chain
      clamp_mark!
    end

    def break_undo_chain!
      @undo_chain = nil
    end

    def snapshot
      [@text.dup, @cursor]
    end

    def restore(snap)
      @text, @cursor = snap
      clamp_cursor!
      @text
    end

    def normalize_count(count)
      n =
        begin
          Integer(count)
        rescue StandardError
          1
        end
      n = 1 if n < 1
      n
    end

    def repeat(count = 1)
      n = normalize_count(count)
      result = nil
      i = 0
      while i < n
        result = yield
        i += 1
      end
      result
    end

    def clamp_range(range)
      raise ArgumentError, "range required" unless range.is_a?(Range)

      len = text.length
      s = range.begin.to_i
      e = range.end.to_i
      e += 1 unless range.exclude_end?

      s = 0 if s < 0
      s = len if s > len
      e = 0 if e < 0
      e = len if e > len
      e = s if e < s

      s...e
    end

    def word_span_forward(from = cursor)
      chars = text.chars
      i = from

      i += 1 while i < chars.length && !word_char?(chars[i])
      i += 1 while i < chars.length && word_char?(chars[i])

      from...i
    end

    def word_span_backward(from = cursor)
      chars = text.chars
      i = from - 1
      return from...from if i < 0

      # skip non-word
      i -= 1 while i > 0 && !word_char?(chars[i])
      # skip word
      i -= 1 while i > 0 && word_char?(chars[i])

      start = i == 0 && word_char?(chars[i]) ? 0 : i + 1
      start...from
    end

    def clamp_cursor!
      @cursor = 0 if @cursor.negative?
      max = @text.length
      @cursor = max if @cursor > max
    end

    def clamp_mark!
      if @mark
        @mark = 0 if @mark.negative?
        max = @text.length
        @mark = max if @mark > max
      end
    end

    def adjust_mark_for_replace_span!(start, removed_len, inserted_len)
      return unless @mark

      s = start.to_i
      rem = removed_len.to_i
      ins = inserted_len.to_i
      delta = ins - rem

      if s <= @mark
        if @mark < s + rem
          # mark was inside removed region; snap to end of inserted region
          @mark = s + ins
        else
          @mark += delta
        end
      end

      clamp_mark!
    end

    def push_kill(str, append: true)
      s = str.to_s
      return if s.empty?

      if @last_action == :kill && !@kill_ring.empty?
        if append
          @kill_ring[0] = @kill_ring[0] + s
        else
          @kill_ring[0] = s + @kill_ring[0]
        end
      else
        @kill_ring.unshift(s)
      end
      @kill_ring.pop while @kill_ring.length > @kill_ring_max
    end

    def word_char?(ch)
      @word_re.match?(ch)
    end
  end
end
