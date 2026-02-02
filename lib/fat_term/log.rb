# frozen_string_literal: true

require "logger"
require "json"
require "time"
require "fileutils"

module FatTerm
  module Logger
    class << self
      attr_accessor :logger
    end

    # Convenience: log structured events without repeating formatting.
    #
    #   FatTerm.log(:decode_getch, ch: 27, note: "escape")
    #
    def self.log(event = nil, level: :debug, tag: nil, **data)
      return unless logger

      # Category gating
      tags = FatTerm::Config.config[:log][:tags] || [:all]
      if tag && tags && tags != "all"
        tags = Array(tags).map(&:to_s)
        return unless tags.include?(tag.to_s)
      end

      lvl = level.to_sym
      payload =
        if data.empty?
          # Allow plain strings naturally
          { event: event&.to_s, tag: tag }
        else
          { event: event&.to_s, tag: tag }.merge(data)
        end

      # Logger takes a string. Encode as JSON by default if the formatter is JSON,
      # or just pass a single-line string payload.
      logger.public_send(lvl.to_sym) { payload.to_json }
    rescue NoMethodError
      # If level is unsupported or logger missing, ignore.
    end

    # One-stop configuration. You can pass an IO, a path, or use STDERR.
    #
    #   FatTerm.configure_logger(path: "/tmp/fat_term.log", level: Logger::DEBUG, json: true)
    #
    def self.configure(level: :info, json: true, progname: "fat_term")
      path =
        if FatTerm::Config.config[:log][:file]
          File.expand_path(FatTerm::Config.config[:log][:file])
        elsif ENV['XDG_STATE_HOME']
          File.expand_path(File.join(ENV['XDG_STATE_HOME'], 'fat_term', 'fat_term.log'))
        else
          File.expand_path(File.join('~/.state/fat_term', 'fat_term.log'))
        end
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      FileUtils.touch(path)
      unless File.readable?(path) && File.writable?(path)
        return self.logger = nil
      end

      case level
      when 'debug', :debug
        ::Logger::DEBUG
      else
        ::Logger::INFO
      end
      self.logger = ::Logger.new(File.open(path, "a"))
      self.logger.level = level
      self.logger.progname = progname
      self.logger.formatter = json ? JsonFormatter.new : TextFormatter.new
      self.logger
    end

    class JsonFormatter < ::Logger::Formatter
      def call(severity, time, progname, msg)
        rec = {
          t: time.utc.iso8601(6),
          sev: severity,
          prog: progname
        }

        # If msg is JSON already (our FatTerm.log uses to_json), parse and merge.
        # Otherwise store as "msg".
        begin
          parsed = JSON.parse(msg.to_s)
          if parsed.is_a?(Hash)
            rec.merge!(parsed)
          else
            rec[:msg] = parsed
          end
        rescue JSON::ParserError
          rec[:msg] = msg.to_s
        end

        rec.to_json << "\n"
      end
    end

    class TextFormatter < ::Logger::Formatter
      def call(severity, time, progname, msg)
        ts = time.utc.iso8601(6)
        "#{ts} #{severity} #{progname} #{msg}\n"
      end
    end
  end

  # So we can just call FatTerm.log
  def self.log(event = nil, level: :debug, **data)
    Logger.log(event, level: level, **data)
  end
end
