# frozen_string_literal: true

module FatTerm
  class History
    DEFAULT_HISTORY_FILE = File.expand_path("~/.fat_term_history")
    DEFAULT_HISTORY_MAX = 10_000

    attr_reader :entries

    def initialize(path: nil, max: nil)
      @path =
        case path
        when :default
          Config.config.dig(:history, :file) || DEFAULT_HISTORY_FILE
        when nil, false
          nil
        else
          path
        end
      @path = File.expand_path(@path) if @path
      @max = max&.to_i || Config.config.dig(:history, :max)&.to_i || DEFAULT_HISTORY_MAX
      @entries = []
      @cursors = {}

      if @path
        FatTerm.info("History loaded from #{@path}")
        load
      else
        FatTerm.info("In-memory History only: no path")
      end
    end

    # A global default History object available to all sessions.  Sets a class
    # instance variable.
    def self.default
      for_path(:default)
    end

    def self.for_path(path = :default)
      @instances ||= {}
      @instances[path] ||= new(path: path)
    end

    def self.reset_instances!
      @instances = {}
    end

    def self.default
      @default ||= new(path: :default)
    end


    ###################################################################################
    # Accessing History items from a consuming application
    ###################################################################################

    include Enumerable

    def each(&block)
      return enum_for(:each) unless block

      @entries.each(&block)
    end

    def for(kind: nil, ctx: nil)
      return enum_for(:for, kind: kind, ctx: ctx) unless block_given?

      each do |entry|
        next if kind && entry.kind != kind.to_sym
        next if ctx && !ctx_match?(entry, ctx)

        yield entry
      end
    end

    def recent(kind: nil, ctx: nil, limit: nil)
      rows = self.for(kind: kind, ctx: ctx).to_a
      rows = rows.last(limit) if limit
      rows.reverse
    end

    ###################################################################################
    # Manipulating History
    ###################################################################################

    def add(text, kind: :command, ctx: nil, stamp: nil)
      text = text.to_s
      return if text.strip.empty?

      kind = kind.to_sym
      ctx = normalize_ctx(ctx)
      entry = Entry.new(text: text, kind: kind, ctx: ctx, stamp: stamp)
      last = @entries.last
      if last && last.text == text && last.kind == kind
        reset_cursor_for(kind, ctx: ctx)
        return text
      end
      @entries << entry
      truncate!
      append_to_file(entry)
      reset_cursor_for(kind, ctx: ctx)
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
      ctx = normalize_ctx(ctx)
      cursor = cursor_for(*kinds, ctx: ctx)
      prefix = cursor[:prefix]

      if cursor[:index].nil?
        cursor[:scratch] = current.to_s
        cursor[:prefix] = current.to_s
        prefix = cursor[:prefix]
      end

      the_entries = entries_for(*kinds, ctx: ctx, prefix: prefix)
      return current.to_s if the_entries.empty?

      if cursor[:index].nil?
        cursor[:index] = the_entries.length - 1
        return the_entries[cursor[:index]].text
      end

      cursor[:index] -= 1 if cursor[:index].positive?
      the_entries[cursor[:index]].text
    end

    def next_for(*kinds, ctx: nil)
      ctx = normalize_ctx(ctx)
      cursor = cursor_for(*kinds, ctx: ctx)
      the_entries = entries_for(*kinds, ctx: ctx, prefix: cursor[:prefix])
      return "" if the_entries.empty? || cursor[:index].nil?

      if cursor[:index] < the_entries.length - 1
        cursor[:index] += 1
        the_entries[cursor[:index]].text
      else
        scratch = cursor[:scratch]
        reset_cursor_for(*kinds, ctx: ctx)
        scratch || ""
      end
    end

    def reset_cursor_for(*kinds, ctx: nil)
      ctx = normalize_ctx(ctx)
      cursor = cursor_for(*kinds, ctx: ctx)
      cursor[:index] = nil
      cursor[:prefix] = nil
      cursor[:scratch] = nil
    end

    def suggest_for(*kinds, prefix:, ctx: nil)
      text = prefix.to_s
      return if text.empty?

      ctx = normalize_ctx(ctx)
      local = ctx ? entries_for(*kinds, ctx: ctx, prefix: text) : []
      return local.last.text unless local.empty?

      global = entries_for(*kinds, prefix: text)
      global.last&.text
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
      ctx = normalize_ctx(ctx)
      key = [normalize_kinds(*kinds), normalize_ctx(ctx)]
      @cursors[key] ||= { index: nil, scratch: nil, prefix: nil }
    end

    def prefix_match?(entry, prefix)
      text = prefix.to_s
      return true if text.empty?

      entry.text.start_with?(text)
    end

    def entries_for(*kinds, ctx: nil, prefix: nil)
      ctx = normalize_ctx(ctx)
      wanted = normalize_kinds(*kinds)

      matches = select do |entry|
        wanted.include?(entry.kind) && prefix_match?(entry, prefix)
      end

      # fallback, preferred = matches.partition { |entry| !ctx_match?(entry, ctx) }
      # fallback + preferred
      fallback, preferred = matches.partition { |entry| !ctx_match?(entry, ctx) }
      # binding.break
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
      FatTerm.error("History#append_to_file failed for #{@path}: #{e.class}: #{e.message}", tag: :history)
    end

    def truncate!
      excess = @entries.length - @max
      return if excess <= 0

      @entries.shift(excess)
      @cursors.clear
    end
  end
end
