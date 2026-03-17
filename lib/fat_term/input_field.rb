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

    # :category: Inspect

    def to_s
      "<InputField:#{object_id}> Prompt => #{prompt} Buffer => #{buffer}"
    end
    alias_method :inspect, :to_s

    # :category: Queries

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

    # :category: Setters

    def prompt=(prompt)
      @prompt = Prompt.ensure(prompt)
    end

    # :category: Autosuggestion

    def autosuggestion
      return if history.nil?

      history.suggest_for(
        resolve_history_kind,
        prefix: buffer.text,
        ctx: resolve_history_ctx,
      )
    end

    def autosuggestion_visible?
      suggestion = autosuggestion.to_s
      text = buffer.text.to_s
      return false if suggestion.empty?
      return false unless suggestion.start_with?(text)

      suggestion != text
    end

    def autosuggestion_suffix
      return "" unless autosuggestion_visible?

      autosuggestion.to_s.delete_prefix(buffer.text.to_s)
    end

    def accept_autosuggestion!
      return unless autosuggestion_visible?

      sync_virtual_suffix!
      buffer.accept_virtual_suffix!
    end

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

    desc "Paste text into the field, normalizing to one line"
    action :paste do |str|
      s = str.to_s
      s = s.gsub(/\r\n?/, "\n")
      s = s.gsub("\n", " ")
      buffer.insert(s)
    end

    def act_on(action, *args, env: nil, **kwargs)
      return unless action

      reset_history_cursor_for(action)

      if FatTerm::Actions.registered?(action)
        if env
          FatTerm::Actions.call(action, env, *args, **kwargs)
        else
          defn = FatTerm::Actions.lookup(action)
          target =
            case defn[:on]
            when :field then self
            when :buffer then buffer
            else
              raise FatTerm::ActionError, "Cannot dispatch #{action} without env for target #{defn[:on].inspect}"
            end
          target.public_send(defn[:method], *args, **kwargs)
        end
      elsif buffer.respond_to?(action)
        buffer.public_send(action, *args, **kwargs)
      elsif respond_to?(action)
        public_send(action, *args, **kwargs)
      else
        raise FatTerm::ActionError, "Unknown action: #{action}"
      end
    end

    def sync_virtual_suffix!
      buffer.virtual_suffix = autosuggestion_suffix
    end

    private

    def reset_history_cursor_for(action)
      return if action.to_s.start_with?("history_")

      history&.reset_cursor_for(resolve_history_kind, ctx: resolve_history_ctx)
    end

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
