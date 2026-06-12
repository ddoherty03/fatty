# frozen_string_literal: true

require "pathname"
require "strscan"

module Fatty
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
      completion_proc: nil,
      history: nil,
      history_kind: :command,
      history_ctx: nil
    )
      @prompt = Prompt.ensure(prompt)
      @history = history
      @history_kind = history_kind
      @history_ctx = history_ctx
      @completion_proc = completion_proc
      @completion_state = nil

      @buffer =
        if buffer
          buffer
        else
          cfg = Fatty::Config.config
          word_chars = cfg.dig(:input_buffer, :word_chars) || Fatty::InputBuffer::DEFAULT_WORD_CHARS
          Fatty::InputBuffer.new(word_chars: word_chars)
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

    def state
      [
        prompt_text.to_s.dup.freeze,
        buffer.text.to_s.dup.freeze,
        buffer.cursor,
        buffer.virtual_suffix.to_s.dup.freeze,
        buffer.region_active?,
        buffer.region_range,
      ]
    end

    # Visual cursor X position in the window
    def cursor_x
      before_cursor = buffer.text.to_s[0...buffer.cursor].to_s
      prompt_width + Fatty::Ansi.visible_length(before_cursor)
    end

    def prompt_text
      prompt.text
    end

    # The prompt might use coloring, so we use the visible length stripped of
    # ANSI controls.
    def prompt_width
      Fatty::Ansi.visible_length(prompt_text.to_s.lines.last.to_s)
    end

    def snapshot_input_state
      [
        prompt_text.to_s.dup.freeze,
        buffer.text.to_s.dup.freeze,
        buffer.virtual_suffix.to_s.dup.freeze,
        cursor_x,
        (r = buffer.region_range) ? [r.begin, r.end] : nil,
      ]
    end

    # :category: Setters

    def prompt=(prompt)
      @prompt = Prompt.ensure(prompt)
    end

    # :category: Actions

    desc "Accept the current line, add to history, and clear the buffer"
    action :accept_line do |save_history: true|
      line = buffer.text.dup
      if save_history && history && !line.empty?
        history.add(
          line,
          kind: resolve_history_kind,
          ctx: resolve_history_ctx,
        )
      end
      buffer.clear
      line
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
      s = s.tr("\n", " ")
      buffer.insert(s)
    end

    def act_on(action, *args, env: nil, **kwargs)
      return unless action

      reset_history_cursor_for(action)

      if Fatty::Actions.registered?(action)
        if env
          Fatty::Actions.call(action, env, *args, **kwargs)
        else
          defn = Fatty::Actions.lookup(action)
          target =
            case defn[:on]
            when :field then self
            when :buffer then buffer
            else
              raise Fatty::ActionError, "Cannot dispatch #{action} without env for target #{defn[:on].inspect}"
            end
          target.public_send(defn[:method], *args, **kwargs)
        end
      elsif buffer.respond_to?(action)
        buffer.public_send(action, *args, **kwargs)
      elsif respond_to?(action)
        public_send(action, *args, **kwargs)
      else
        raise Fatty::ActionError, "Unknown action: #{action}"
      end
    end

    # :category: Completion

    def autosuggestion
      active = active_completion_autosuggestion
      return active if active

      return if buffer.text.empty?

      default_completion_autosuggestion || history_autosuggestion
    end

    def autosuggestion
      active = active_completion_autosuggestion
      return active if active

      text = buffer.text.to_s
      return if text.empty?

      autosuggestion_candidates.first
    end

    def completion_candidates
      return [] unless @completion_proc

      Array(@completion_proc.call(buffer))
        .compact
        .map(&:to_s)
        .reject(&:empty?)
        .uniq
    end

    def completion_suggestions
      if path_completion_candidates.any?
        path_completion_candidates
          .map { |candidate| build_line_with_completion(candidate, range: path_completion_range) }
          .reject { |line| line == buffer.text.to_s }
          .uniq
      else
        completion_candidates
          .map { |candidate| build_line_with_completion(candidate, range: completion_replace_range) }
          .reject { |line| line == buffer.text.to_s }
          .uniq
      end
    end

    def autosuggestion_candidates
      text = buffer.text.to_s

      (history_autosuggestions + completion_suggestions)
        .compact
        .map(&:to_s)
        .select { |candidate| candidate.start_with?(text) }
        .reject { |candidate| candidate == text }
        .uniq
    end

    def default_completion_autosuggestion
      completion_suggestions.first
    end

    def active_completion_autosuggestion
      return unless @completion_state

      text = buffer.text.to_s
      if @completion_state[:base] == text &&
         @completion_state[:index] &&
         !@completion_state[:candidates].empty?
        @completion_state[:candidates][@completion_state[:index]]
      end
    end

    def cycle_completion!(direction: 1)
      text = buffer.text.to_s
      candidates = autosuggestion_candidates
      result = nil

      if candidates.empty?
        reset_completion_state!
      elsif same_completion_state?(base: text, candidates: candidates)
        @completion_state[:index] =
          (@completion_state[:index] + direction) % @completion_state[:candidates].length
        result = @completion_state[:candidates][@completion_state[:index]]
      else
        @completion_state = {
          base: text,
          candidates: candidates,
          index: 0,
        }
        result = @completion_state[:candidates].first
      end

      sync_virtual_suffix!
      result
    end

    def reset_completion_state!
      @completion_state = nil
    end

    def completion_replace_range
      text = buffer.text.to_s
      cur = buffer.cursor.to_i
      before = text[0...cur].to_s

      token = before[/\S+\z/].to_s
      start = cur - token.length

      start...cur
    end

    def completion_prefix
      text[0...cursor].to_s[/\S+\z/].to_s
    end

    def history_autosuggestions
      return [] if history.nil?

      history.suggestions_for(
        resolve_history_kind,
        prefix: buffer.text,
        ctx: resolve_history_ctx,
      )
    end

    def path_completion_candidates
      prefix = path_completion_prefix
      return [] if prefix.nil? || prefix.empty?

      rendered_path_candidates(prefix)
    end

    def path_like_prefix?(prefix)
      s = prefix.to_s
      return false if s.empty?

      s.start_with?("/", "~/", "./", "../") || s.include?("/")
    end

    def path_completion_prefix
      r = path_completion_range
      return if r.nil?

      buffer.text[r].to_s
    end

    # Use a StringScanner to determine where a pathname occurs before the
    # cursor for purposes of providing completions.  It considers escaped
    # characters, including escaped whitespace as part of a plausible
    # pathname.
    def path_completion_range
      text = buffer.text.to_s
      cur  = buffer.cursor
      return if cur < 0

      before = text[0...cur]
      scanner = StringScanner.new(before)

      last_token = nil
      until scanner.eos?
        next if scanner.scan(/\s+/)

        if (token = scanner.scan(/(?:\\.|[^\s\\])+/))
          last_token = [scanner.pos - token.length, scanner.pos]
        else
          scanner.getch
        end
      end

      return unless last_token

      start_i, end_i = last_token
      prefix = before[start_i...end_i]

      return unless path_like_prefix?(unescape_path(prefix))

      start_i...end_i
    end

    def rendered_path_candidates(prefix)
      raw_prefix = unescape_path(prefix)
      expanded = expand_path_prefix(raw_prefix)
      return [] if expanded.nil? || expanded.empty?

      if File.directory?(expanded) && !raw_prefix.end_with?("/")
        return [escape_path("#{raw_prefix}/")]
      end

      if raw_prefix.end_with?("/")
        dir_part = expanded
        base_part = ""
      else
        dir_part  = File.dirname(expanded)
        base_part = File.basename(expanded)
      end

      dir_part = "." if dir_part.nil? || dir_part.empty?
      return [] unless Dir.exist?(dir_part)

      # Sort normal directories, normal files, hidden directories, then hidden
      # files, but not if the prefix starts with '.' or '#', then treat hidden
      # files normally.
      entries =
        Dir.children(dir_part)
          .select { |name| name.start_with?(base_part) }
          .sort_by do |name|
            full = File.join(dir_part, name)
            hide_penalty =
              if base_part.match?(/\A[.#]/)
                0
              else
                name.match?(/\A[.#]/) ? 1 : 0
              end
            file_penalty = File.directory?(full) ? 0 : 1
            [hide_penalty, file_penalty, name]
        end

      return [] if entries.empty?

      entries.map do |chosen|
        full = File.join(dir_part, chosen)

        rendered =
          if raw_prefix.start_with?("~/")
            File.join("~", full.delete_prefix("#{Dir.home}/"))
          elsif raw_prefix.start_with?("./") && dir_part == "."
            "./#{chosen}"
          elsif raw_prefix.start_with?("../") && dir_part.start_with?("..")
            File.join(dir_part, chosen)
          elsif raw_prefix.start_with?("/")
            full
          elsif raw_prefix.end_with?("/")
            "#{raw_prefix}#{chosen}"
          elsif raw_prefix.include?("/")
            File.join(File.dirname(raw_prefix), chosen)
          else
            chosen
          end

        rendered += "/" if File.directory?(full) && !rendered.end_with?("/")
        escape_path(rendered)
      end
    end

    def escape_path(path)
      path.gsub(/([ \t\n\\'"`$!#&()*;<>?\[\]\{\}|])/) { "\\#{$1}" }
    end

    def unescape_path(path)
      path.to_s.gsub(/\\(.)/, '\1')
    end

    def expand_path_prefix(prefix)
      s = prefix.to_s
      return if s.empty?

      if s.start_with?("~/")
        File.join(Dir.home, s.delete_prefix("~/"))
      else
        s
      end
    end

    def build_line_with_completion(candidate, range:)
      text = buffer.text.to_s
      before = text[0...range.begin].to_s
      current = text[range].to_s
      after = text[range.end..].to_s
      candidate = candidate.to_s

      replacement =
        if !current.empty? && candidate.downcase.start_with?(current.downcase)
          "#{current}#{candidate[current.length..]}"
        else
          candidate
        end

      "#{before}#{replacement}#{after}"
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

    def popup_completion_candidates
      path_prefix = popup_path_completion_prefix
      if path_prefix
        path = rendered_path_candidates(path_prefix)
        return path if path.any?
      end

      return [] unless @completion_proc

      Array(@completion_proc.call(buffer))
        .compact
        .map(&:to_s)
        .reject(&:empty?)
        .uniq
    end

    def popup_path_completion_prefix
      prefix = path_completion_prefix
      return if prefix.nil? || prefix.empty?

      raw_prefix = unescape_path(prefix)
      expanded = expand_path_prefix(raw_prefix)
      return prefix unless File.directory?(expanded)

      if raw_prefix.end_with?("/")
        prefix
      else
        escape_path("#{raw_prefix}/")
      end
    end

    def popup_completion_range
      path_completion_range || buffer.completion_replace_range
    end

    def popup_completion_query
      path_completion_prefix || buffer.completion_prefix
    end

    def sync_virtual_suffix!
      buffer.virtual_suffix = autosuggestion_suffix
    end

    private

    def same_completion_state?(base:, candidates:)
      @completion_state &&
        @completion_state[:base] == base &&
        @completion_state[:candidates] == candidates &&
        @completion_state[:index]
    end

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
