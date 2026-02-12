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

    attr_reader :buffer, :prompt, :history, :pending_count

    def initialize(prompt:, buffer: nil, history: nil)
      @prompt  = Prompt.ensure(prompt)
      @history = history
      @pending_count = nil

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
    # - Optionally applies a pending count to the next countable action
    #
    def act_on(action, *args, env: nil, **kwargs)
      return unless action

      history&.reset_cursor unless action.to_s.start_with?("history_")

      env ||= FatTerm::ActionEnvironment.new(
        buffer: buffer,
        field: self,
      )
      FatTerm.log(
        "InputField.act_on: action=#{action} args=#{args.inspect} pending_count=#{@pending_count}",
        tag: :count,
      )
      kwargs = add_count_to_args(action, kwargs, @pending_count)
      FatTerm.log("InputField.act_on: args_with_count=#{kwargs}", tag: :count)
      if FatTerm::Actions.registered?(action)
        FatTerm::Actions.call(action, env, *args, **kwargs)
      elsif buffer.respond_to?(action)
        buffer.public_send(action, *args, **kwargs)
      elsif respond_to?(action)
        public_send(action, *args, **kwargs)
      else
        raise FatTerm::ActionError, "Unknown action: #{action}"
      end
    ensure
      clear_count unless count_accumulator?(action)
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

    # category: Count (prefix arg)

    desc "Start / extend a universal argument (C-u): 4, 16, 64..."
    action :universal_argument do
      if @pending_count
        @pending_count *= 4
      else
        @pending_count = 4
      end
      @pending_count
    end

    desc "Accumulate a digit into the pending count (M-<digit> or after C-u)."
    action :meta_digit do |digit|
      digit_argument(digit)
    end

    desc "Accumulate a digit into the pending count (used by meta_digit)."
    action :digit_argument do |digit|
      d = digit.to_i
      d = 0 if d.negative?
      d = 9 if d > 9

      if @pending_count
        @pending_count = (@pending_count * 10) + d
      else
        @pending_count = d
      end
      @pending_count
    end

    desc "Clear any pending count."
    action :clear_count do
      @pending_count = nil
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

    private

    def count_accumulator?(action)
      return false unless action

      sym = action.to_sym
      sym == :universal_argument ||
        sym == :meta_digit ||
        sym == :digit_argument ||
        sym == :clear_count
    end

    def add_count_to_args(action, kwargs, pending_count)
      new_kwargs = kwargs.dup
      if !new_kwargs.key?(:count) && pending_count
        if buffer.respond_to?(action) && buffer.countable?(action)
          new_kwargs[:count] = pending_count
        end
      end
      new_kwargs
    end
  end
end
