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

    def self.configure
      progname = FatTerm::Config.progname
      cfg = FatTerm::Config.config || 'fat_term'
      path =
        if cfg.dig(:log, :file)
          File.expand_path(cfg.dig(:log, :file))
        elsif ENV['XDG_STATE_HOME']
          File.expand_path(File.join(ENV['XDG_STATE_HOME'], progname, "#{progname}.log"))
        else
          File.expand_path(File.join("~/.state/#{progname}", "#{progname}.log"))
        end
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      FileUtils.touch(path)
      unless File.readable?(path) && File.writable?(path)
        return self.logger = nil
      end

      io = File.open(path, "a")
      io.sync = true
      self.logger = ::Logger.new(io)
      logger.level = severity(cfg.dig(:log, :level))
      logger.formatter =
        if cfg.dig(:log, :format).nil?
          JsonFormatter.new
        elsif cfg.dig(:log, :format)&.to_sym == :json
          JsonFormatter.new
        else
          TextFormatter.new
        end
      logger.progname = progname
      logger
    end

    # Convenience: log structured events without repeating formatting.
    #
    #   FatTerm.log(:decode_getch, ch: 27, note: "escape")
    #
    #   Supported tags are:
    #     - keycode:: raw curses input / bytes / ESC buffering
    #     - keyevent:: constructed KeyEvent normalization (ctrl/meta mapping)
    #     - keybinding:: KeyMap#resolve hits/misses, contexts used
    #     - action:: Actions.call, target selection, unknown action
    #     - command:: Terminal.apply_command / :send dispatches
    #     - session:: session update calls, mode/context stack changes
    #     - render:: viewports, layout sizes, redraw triggers
    #     - perf:: timings, frame time, slow paths
    #     - all:: All of the above
    #
    def self.log(event = nil, level: :debug, tag: nil, **data)
      return unless logger

      tags = FatTerm::Config.config.dig(:log, :tags) || [:all]
      tags = Array(tags).map(&:to_sym)

      if tag && !tags.include?(:all)
        return unless tags.include?(tag.to_sym)
      end

      payload = { event: event&.to_s, tag: tag&.to_s }.merge(data)

      logger.add(severity(level)) { payload.to_json }
    rescue StandardError => ex
      # Last-ditch: never let logging take down the app.
      begin
        logger&.add(::Logger::FATAL) do
          { event: "logger_error", err: ex.class.name, msg: ex.message, bt: ex.backtrace&.take(10) }.to_json
        end
      rescue StandardError => ex
        # swallow
      end
    end

    # Translate our severity symbols to those expected by ::Logger.
    def self.severity(sym)
      case sym&.to_sym
      when :debug
        # This is 0
        ::Logger::DEBUG
      when :info
        # This is 1
        ::Logger::INFO
      when :warn
        # This is 2
        ::Logger::WARN
      when :error
        # This is 3
        ::Logger::ERROR
      when :fatal
        # This is 4
        ::Logger::FATAL
      else
        ::Logger::DEBUG
      end
    end

    class JsonFormatter < ::Logger::Formatter
      def call(level, time, progname, msg)
        rec = {
          t: time.utc.iso8601(6),
          sev: level,
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
      def call(level, time, progname, msg)
        ts = time.utc.iso8601(6)
        "#{ts} #{level} #{progname} #{msg}\n"
      end
    end
  end

  # So we can just call FatTerm.log
  def self.log(event = nil, level: :debug, tag: nil, **data)
    Logger.log(event, level: level, tag: tag, **data)
  end

  def self.debug(event, tag: nil, **data)
    Logger.log(event, level: :debug, tag: tag, **data)
  end

  def self.info(event, tag: nil, **data)
    Logger.log(event, level: :info, tag: tag, **data)
  end

  def self.warn(event, tag: nil, **data)
    Logger.log(event, level: :warn, tag: tag, **data)
  end

  def self.error(event, tag: nil, **data)
    Logger.log(event, level: :error, tag: tag, **data)
  end

  def self.fatal(event, tag: nil, **data)
    Logger.log(event, level: :fatal, tag: tag, **data)
  end
end
