# frozen_string_literal: true

module Fatty
  class StatusSession < Session
    DEFAULT_MAX_ROWS = 4

    attr_reader :text, :role

    def id = :status

    def initialize
      super(views: [Fatty::StatusView.new])
      clear
    end

    def update_cmd(name, payload)
      old_rows = rows
      case name
      when :show
        set(payload)
      when :clear
        clear
      end
      new_rows = rows
      if old_rows != new_rows
        [Fatty::Command.terminal(:refresh_layout)]
      else
        []
      end
    end

    def view(renderer:)
      return unless visible?

      renderer.render_status(
        text,
        role: role || :info,
      )
    end

    def rows
      return 0 unless visible?

      lines.length.clamp(1, max_rows)
    end

    def max_rows
      Fatty::Config.config.dig(:status, :max_rows)&.to_i || DEFAULT_MAX_ROWS
    end

    def lines
      @text.to_s
        .lines
        .flat_map { |line| wrap_line(line.chomp, width) }
        .last(max_rows)
    end

    def visible?
      @text && !@text.empty?
    end

    private

    def set(payload)
      @text = payload[:text]
      @role = payload[:role] || :info
    end

    def clear
      @text = nil
      @role = :info
    end

    def wrap_line(line, width)
      text = Fatty::Ansi.strip(line.to_s)
      return [""] if text.empty?

      text.scan(/.{1,#{[width, 1].max}}/)
    end

    def width
      terminal&.screen&.cols || 80
    end
  end
end
