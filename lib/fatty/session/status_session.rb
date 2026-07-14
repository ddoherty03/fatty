# frozen_string_literal: true

module Fatty
  class StatusSession < Session
    DEFAULT_MAX_ROWS = 6

    attr_reader :text, :role

    def initialize(id: nil)
      super
      @text = nil
      @role = :info
    end

    #########################################################################################
    # Session Protocol
    #########################################################################################

    def update(command)
      Fatty.debug(
        "StatusSession before action=#{command.action} text=#{text.inspect}",
        tag: :session,
      )
      log_update(command)
      old_rows = rows
      case command.action
      when :show
        set(command.payload)
      when :clear
        clear
      end
      Fatty.debug(
        "StatusSession after action=#{command.action} text=#{text.inspect}",
        tag: :session,
      )
      new_rows = rows
      commands = []
      if old_rows != new_rows
        commands << Command.terminal(:set_status_rows, rows: new_rows)
        commands << Command.terminal(:refresh_layout)
      end
      commands.compact
    end

    def view
      return unless visible?

      renderer.render_status(self)
    end

    #########################################################################################
    # Other public API methods
    #########################################################################################

    def state
      [
        text.dup.freeze,
        role.dup,
        renderer.screen.status_rect.row.dup,
        renderer.screen.status_rect.rows.dup,
        renderer.screen.status_rect.cols.dup,
        renderer.theme_version
      ]
    end

    private

    # simplecov:disable

    def rows
      return 0 unless visible?

      lines.length.clamp(1, max_rows)
    end

    def max_rows
      Fatty::Config.config.dig(:status, :max_rows)&.to_i || DEFAULT_MAX_ROWS
    end

    def lines
      renderable_text(@text)
        .lines
        .flat_map { |line| wrap_line(line.chomp, width) }
        .last(max_rows)
    end

    def renderable_text(value)
      parts = value.is_a?(Array) ? value : [value]

      parts.map do |part|
        if part.is_a?(Hash) && part.key?(:text)
          part[:text].to_s
        else
          part.to_s
        end
      end.join
    end

    def visible?
      @text && !@text.empty?
    end

    def set(payload)
      new_text = chomp_text(payload.fetch(:text))
      new_role = payload[:role] || :info

      if payload[:append] && visible?
        @text = status_parts(@text, role)
                  .push(
                    "\n",
                    {
                      text: new_text,
                      role: new_role,
                    },
                  )
      else
        @text = new_text
        @role = new_role
      end
    end

    def status_parts(text, role)
      if text.is_a?(Array)
        text.dup
      else
        [
          {
            text: text,
            role: role,
          },
        ]
      end
    end

    def chomp_text(text)
      case text
      when String
        text.chomp
      when Array
        text = text.dup
        index = text.rindex { |segment| segment.is_a?(String) && !segment.empty? }
        text[index] = text[index].chomp if index
        text
      else
        text
      end
    end

    def clear
      return unless visible?

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
