# frozen_string_literal: true

module FatTerm
  class History
    DEFAULT_HISTORY_FILE = File.expand_path("~/.fat_term_history")
    DEFAULT_HISTORY_MAX = 10_000

    attr_reader :entries

    def initialize(path: nil, max: nil)
      @path = path || Config.config.dig(:history, :file) || DEFAULT_HISTORY_FILE
      @path = File.expand_path(@path)
      @max = max&.to_i || Config.config.dig(:history, :max)&.to_i || DEFAULT_HISTORY_MAX
      @entries = []
      @cursors = {}

      load if @path
    end

    def add(text, kind: :command, ctx: nil, stamp: nil)
      text = text.to_s
      return if text.strip.empty?

      kind = kind.to_sym
      entry = Entry.new(text: text, kind: kind, ctx: ctx, stamp: stamp)
      last = @entries.last
      if last && last.text == text && last.kind == kind
        reset_cursor_for(kind)
        return text
      end
      @entries << entry
      truncate!
      append_to_file(entry)
      reset_cursor_for(kind)
      text
    end

    def previous(current)
      previous_for(:command, current: current)
    end

    def next
      next_for(:command)
    end

    def reset_cursor
      reset_cursor_for(:command)
    end

    def previous_for(*kinds, current:, ctx: nil)
      cursor = cursor_for(*kinds, ctx: ctx)
      prefix = cursor[:prefix]

      if cursor[:index].nil?
        cursor[:scratch] = current.to_s
        cursor[:prefix] = current.to_s
        prefix = cursor[:prefix]
      end

      entries = entries_for(*kinds, ctx: ctx, prefix: prefix)
      return current.to_s if entries.empty?

      if cursor[:index].nil?
        cursor[:index] = entries.length - 1
        return entries[cursor[:index]].text
      end

      cursor[:index] -= 1 if cursor[:index].positive?
      entries[cursor[:index]].text
    end

    def next_for(*kinds, ctx: nil)
      cursor = cursor_for(*kinds, ctx: ctx)
      entries = entries_for(*kinds, ctx: ctx, prefix: cursor[:prefix])
      return "" if entries.empty? || cursor[:index].nil?

      if cursor[:index] < entries.length - 1
        cursor[:index] += 1
        entries[cursor[:index]].text
      else
        scratch = cursor[:scratch]
        reset_cursor_for(*kinds, ctx: ctx)
        scratch || ""
      end
    end

    def reset_cursor_for(*kinds, ctx: nil)
      cursor = cursor_for(*kinds, ctx: ctx)
      cursor[:index] = nil
      cursor[:prefix] = nil
    end

    private

    def normalize_kinds(*kinds)
      kinds.flatten.map(&:to_sym).uniq.sort
    end

    def normalize_ctx(ctx)
      return {} unless ctx.is_a?(Hash)

      ctx.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end.sort.to_h
    end

    def ctx_match?(entry, ctx)
      wanted = normalize_ctx(ctx)
      return true if wanted.empty?

      wanted.all? do |key, value|
        entry.ctx_fetch(key) == value
      end
    end

    def cursor_for(*kinds, ctx: nil)
      key = [normalize_kinds(*kinds), normalize_ctx(ctx)]
      @cursors[key] ||= { index: nil, scratch: nil, prefix: nil }
    end

    def prefix_match?(entry, prefix)
      text = prefix.to_s
      return true if text.empty?

      entry.text.start_with?(text)
    end

    def entries_for(*kinds, ctx: nil, prefix: nil)
      wanted = normalize_kinds(*kinds)
      entries = @entries.select do |entry|
        wanted.include?(entry.kind) && prefix_match?(entry, prefix)
      end
      preferred = []
      fallback = []

      entries.each do |entry|
        if ctx_match?(entry, ctx)
          preferred << entry
        else
          fallback << entry
        end
      end
      fallback + preferred
    end

    def load
      @entries.clear
      @cursors.clear
      return unless File.exist?(@path)

      File.foreach(@path) do |line|
        line = line.chomp
        next if line.empty?

        entry = parse_history_line(line)
        @entries << entry if entry
      end
      truncate!
    end

    def parse_history_line(line)
      hash = JSON.parse(line)
      Entry.from_h(hash)
    rescue JSON::ParserError
      Entry.new(text: line, kind: :command)
    rescue StandardError
      nil
    end

    def append_to_file(entry)
      return unless @path

      dir = File.dirname(@path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

      File.open(@path, "a") do |f|
        f.puts(JSON.generate(entry.to_h))
        f.flush
        f.fsync
      end
    rescue => e
      warn "fat_term: failed to write history: #{e.message}"
    end

    def truncate!
      excess = @entries.length - @max
      return if excess <= 0

      @entries.shift(excess)
      @cursors.clear
    end
  end
end
