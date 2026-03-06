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

    def previous_for(*kinds, current)
      entries = entries_for(*kinds)
      return current.to_s if entries.empty?

      cursor = cursor_for(*kinds)

      if cursor[:index].nil?
        cursor[:scratch] = current.to_s
        cursor[:index] = entries.length - 1
        return entries[cursor[:index]].text
      end

      cursor[:index] -= 1 if cursor[:index].positive?
      entries[cursor[:index]].text
    end

    def next_for(*kinds)
      entries = entries_for(*kinds)
      cursor = cursor_for(*kinds)
      return "" if entries.empty? || cursor[:index].nil?

      if cursor[:index] < entries.length - 1
        cursor[:index] += 1
        entries[cursor[:index]].text
      else
        scratch = cursor[:scratch]
        reset_cursor_for(*kinds)
        scratch || ""
      end
    end

    def reset_cursor_for(*kinds)
      cursor = cursor_for(*kinds)
      cursor[:index] = nil
      cursor[:scratch] = nil
    end

    private

    def normalize_kinds(*kinds)
      kinds.flatten.map(&:to_sym).uniq.sort
    end

    def cursor_for(*kinds)
      key = normalize_kinds(*kinds)
      @cursors[key] ||= { index: nil, scratch: nil }
    end

    def entries_for(*kinds)
      wanted = normalize_kinds(*kinds)
      @entries.select { |entry| wanted.include?(entry.kind) }
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
