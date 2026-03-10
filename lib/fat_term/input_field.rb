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
    include Actionable

    attr_reader :buffer, :prompt, :history

    def initialize(
      prompt:,
      buffer: nil,
      history: nil,
      history_kind: :command,
      history_ctx: nil
    )
      @prompt = Prompt.ensure(prompt)
      @history = history
      @history_kind = history_kind
      @history_ctx = history_ctx

      @buffer =
        if buffer
          buffer
        else
          cfg = FatTerm::Config.config
          word_chars = cfg.dig(:input_buffer, :word_chars) || FatTerm::InputBuffer::DEFAULT_WORD_CHARS
          FatTerm::InputBuffer.new(word_chars: word_chars)
        end
    end

    def prompt=(prompt)
      @prompt = Prompt.ensure(prompt)
    end

    # Centralized action dispatch for this field.
    # - Resets history cursor for non-history actions
    # - Executes the registered action via FatTerm::Actions
    #
    def act_on(action, *args, env: nil, **kwargs)
      return unless action

      unless action.to_s.start_with?("history_")
        history&.reset_cursor_for(resolve_history_kind, ctx: resolve_history_ctx)
      end

      env ||= FatTerm::ActionEnvironment.new(
        buffer: buffer,
        field: self,
      )
      FatTerm.log(
        "InputField.act_on: action=#{action} args=#{args.inspect}",
        tag: :count,
      )
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
      if history
        history.add(
          line,
          kind: resolve_history_kind,
          ctx: resolve_history_ctx,
        )
        buffer.clear
        line
      end
    end

    desc "Replace buffer with the previous history entry"
    action :history_prev do
      return unless history

      buffer.replace(history.previous_for(resolve_history_kind, current: buffer.text, ctx: resolve_history_ctx))
    end

    desc "Replace buffer with the next history entry"
    action :history_next do
      return unless history

      buffer.replace(history.next_for(resolve_history_kind, ctx: resolve_history_ctx))
    end

    private

    def resolve_history_kind
      value = @history_kind
      value = instance_exec(&value) if value.respond_to?(:call)
      value.to_sym
    end

    def resolve_history_ctx
      value = @history_ctx
      value = instance_exec(&value) if value.respond_to?(:call)
      value.is_a?(Hash) ? value : {}
    end
  end
end
