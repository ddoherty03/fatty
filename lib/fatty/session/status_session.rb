# frozen_string_literal: true

module Fatty
  class StatusSession < Session
    DEFAULT_STATUS_MAX_ROWS = 4

    attr_reader :text, :role

    def id = :status

    def initialize
      super(views: [Fatty::StatusView.new])
      clear
    end

    def update(message)
      kind, name, payload = message
      commands =
        if kind == :cmd
          case name
          when :show
            set(text: payload[:text], role: payload[:role])
          when :clear
            clear
          else
            []
          end
        else
          []
        end

      commands
    end

    def visible?
      @text && !@text.empty?
    end

    def clear
      @text = nil
      @role = :info
    end

    private

    def update_cmd(name, payload)
      old_rows = rows(width: terminal&.screen&.cols || 80)
      case name
      when :show
        set(payload)
      when :clear
        clear
      end
      new_rows = rows(width: terminal&.screen&.cols || 80)

      if old_rows != new_rows
        [[:terminal, :refresh_layout]]
      else
        []
      end
    end

    def set(payload)
      @text = payload[:text]
      @role = payload[:role] || :info
    end

    def status_rows
      return 0 unless status_visible?

      status_lines.length.clamp(1, status_max_rows)
    end

    def status_max_rows
      Fatty::Config.config.dig(:status, :max_rows)&.to_i || DEFAULT_STATUS_MAX_ROWS
    end

    def status_lines
      width = screen&.cols || 80

      @status_text.to_s
        .lines
        .flat_map { |line| wrap_status_line(line.chomp, width) }
        .last(status_max_rows)
    end
  end
end
