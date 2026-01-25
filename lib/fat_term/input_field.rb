# frozen_string_literal: true

module FatTerm
#   The =InputField= class is a thin controller around an InputBuffer that
#   adds:
#   - A prompt (text shown before the editable buffer)
#   - Optional command history integration (previous/next)
#   - A small set of "editor actions" intended to be bound to keys
#
#   =InputField= intentionally does *not* perform terminal I/O or rendering.
#   Higher-level UI components (e.g., Terminal/Screen/widgets) are responsible
#   for:
#
#   - Decoding keys and dispatching actions
#   - Translating buffer/cursor state into screen coordinates
#   - Drawing the prompt + buffer text and placing the cursor
#
#   Word-motion and word-deletion semantics are delegated to InputBuffer so
#   the definition of "word" can be configured in one place (via
#   =InputBuffer='s word_chars/word_re).
  class InputField
    include FatTerm::Actionable

    attr_reader :buffer, :prompt, :history

    def initialize(prompt:, buffer: nil, history: nil)
      @prompt  = prompt
      @history = history

      @buffer =
        if buffer
          buffer
        else
          cfg = FatTerm::Config.config
          word_chars = cfg.dig(:input_buffer, :word_chars) || FatTerm::InputBuffer::DEFAULT_WORD_CHARS
          FatTerm::InputBuffer.new(word_chars: word_chars)
        end
    end

    # Centralized action dispatch for this field.
    # - Resets history cursor for non-history actions
    # - Executes the registered action via FatTerm::Actions
    #
    # NOTE: Printable character insertion is usually handled by the input loop
    # (Actions.call(:insert, ctx, ch)) rather than mapping in keybindings.
    def act_on(action, *args, ctx: nil)
      return unless action

      history&.reset_cursor unless action.to_s.start_with?("history_")

      ctx ||= FatTerm::ActionContext.new(
        buffer: buffer,
        field: self,
      )

      FatTerm::Actions.call(action, ctx, *args)
    end

    # category: Queries

    def empty?
      buffer.text == ""
    end

    # Visual cursor X position in the window (ASCII for now)
    def cursor_x
      prompt_width + buffer.cursor
    end

    def prompt_text
      prompt.text
    end

    def prompt_width
      prompt_text.length
    end

    # category: Actions

    desc "Accept the current line, add to history, and clear the buffer"
    action :accept_line do
      line = buffer.text.dup
      history&.add(line)
      buffer.clear
      line
    end

    desc "Replace buffer with the previous history entry"
    action :history_prev do
      return unless history

      buffer.replace(history.previous(buffer.text))
    end

    desc "Replace buffer with the next history entry"
    action :history_next do
      return unless history

      buffer.replace(history.next)
    end
  end
end
