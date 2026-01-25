# frozen_string_literal: true

module FatTerm
  class History
    DEFAULT_MAX = 10_000

    attr_reader :entries

    def initialize(path: nil, max: DEFAULT_MAX)
      @path    = path
      @max     = max
      @entries = []
      @index   = nil
      @scratch = nil

      load if @path
    end

    def add(line)
      return if line.strip.empty?
      return if @entries.last == line

      @entries << line
      truncate!
      append_to_file(line)
      reset_cursor
    end

    def previous(current)
      return current.to_s if @entries.empty?

      if @index.nil?
        @scratch = current.to_s
        @index = @entries.length - 1
        return @entries[@index]
      end

      @index -= 1 if @index.positive?
      @entries[@index]
    end

    def next
      return "" if @entries.empty? || @index.nil?

      if @index < @entries.length - 1
        @index += 1
        @entries[@index]
      else
        scratch = @scratch
        reset_cursor
        scratch || ""
      end
    end

    def reset_cursor
      @index = nil
      @scratch = nil
    end

    private

    def load
      return unless File.exist?(@path)

      File.foreach(@path) do |line|
        line = line.chomp
        @entries << line unless line.empty?
      end

      truncate!
    end

    def append_to_file(line)
      return unless @path

      File.open(@path, "a") do |f|
        f.puts(line)
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
    end
  end
end
