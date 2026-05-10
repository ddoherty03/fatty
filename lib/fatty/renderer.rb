# frozen_string_literal: true

module Fatty
  class Renderer
    attr_reader :screen, :palette, :context

    def initialize(screen:, palette:, context:)
      @screen = screen
      @palette = palette
      @context = context
      @last_status_state = nil
      @last_alert_state = nil
    end

    def screen=(screen)
      @screen = screen
      @legacy.screen = screen if defined?(@legacy) && @legacy.respond_to?(:screen=)
    end

    def render_output(...)
      raise NotImplementedError, "#{self.class} must implement #render_output"
    end

    def render_status(...)
      raise NotImplementedError, "#{self.class} must implement #render_status"
    end

    def render_input_field(...)
      raise NotImplementedError, "#{self.class} must implement #render_input_field"
    end

    def render_pager_field(...)
      raise NotImplementedError, "#{self.class} must implement #render_pager_field"
    end

    def render_popup(...)
      raise NotImplementedError, "#{self.class} must implement #render_popup"
    end

    def render_prompt_popup(...)
      raise NotImplementedError, "#{self.class} must implement #render_prompt_popup"
    end

    def render_alert(...)
      raise NotImplementedError, "#{self.class} must implement #render_alert"
    end

    def invalidate!
      @last_status_state = nil
      @legacy.invalidate! if defined?(@legacy) && @legacy.respond_to?(:invalidate!)
      nil
    end

    protected

    def status_line(text, width:)
      msg = text.to_s.tr("\r\n", " ")
      msg.ljust(width)[0, width]
    end

    def pager_field_line(field, width:)
      prompt = field.prompt_text.to_s
      buf_text = field.buffer.text.to_s
      text = (prompt + buf_text).tr("\r\n", "")
      visible = Fatty::Ansi.plain_text(text)

      visible[0, width].ljust(width)
    end
    private

    def queue_ansi_line(...)
      @legacy.queue_ansi_line(...)
    end
  end
end

require_relative 'renderer/curses.rb'
require_relative 'renderer/truecolor.rb'
