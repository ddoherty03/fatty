# frozen_string_literal: true

# This Struct encapsulates the geometry of popup windows often needed in
# rendering.
PopupLayout = Struct.new(
  :row,
  :width,
  :height,
  keyword_init: true,
)

module Fatty
  # The Renderer class implements drawing the elements of a Fatty terminal
  # (output, input, alert, status, and popups) on the screen.  There are two
  # ways of doing so: (1) using normal curses operations with curses-defined
  # pairs and (2) using ANSI codes to write with a Truecolor full-color
  # palette.  This class is the base class for those two rendering methods and
  # provides methods common to them.
  class Renderer
    FRAME_STYLES = {
      ascii: { h: "-", v: "|" },
      single: { h: "─", v: "│" },
      double: { h: "═", v: "║" },
    }.freeze

    CORNER_STYLES = {
      square: {
        ascii: { tl: "+", tr: "+", bl: "+", br: "+" },
        single: { tl: "┌", tr: "┐", bl: "└", br: "┘" },
        double: { tl: "╔", tr: "╗", bl: "╚", br: "╝" },
      },
      rounded: {
        single: { tl: "╭", tr: "╮", bl: "╰", br: "╯" },
      },
    }.freeze

    POPUP_SELECTED_GUTTER = "▶ "
    POPUP_UNSELECTED_GUTTER = "  "

    attr_reader :screen, :palette, :context

    def initialize(screen:, palette:, context:)
      @screen = screen
      @palette = palette
      @context = context
      @last_status_state = nil
      @last_alert_state = nil
      @last_popup_state = nil
    end

    def screen=(screen)
      @screen = screen
      @legacy.screen = screen if defined?(@legacy) && @legacy.respond_to?(:screen=)
    end

    def apply_theme!(theme)
      Fatty::Themes::Manager.set(theme)
      # Renderer invariant:
      # @palette is always a fully resolved palette (never raw spec)
      @palette = context.apply_theme!(Fatty::Themes::Manager.current)
      invalidate!
      sync_backgrounds!
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
      @last_output_state = nil
      @last_input_state = nil
      @last_alert_state = nil
      @last_status_state = nil
      @last_pager_field_state = nil
      @last_popup_state = nil
      @legacy.invalidate! if defined?(@legacy) && @legacy.respond_to?(:invalidate!)
    end

    protected

    def alert_state(alert)
      [
        alert&.message,
        alert&.role,
        alert&.details,
        screen.alert_rect.row,
        screen.alert_rect.cols,
      ]
    end

    def status_state(text, role)
      [
        text.to_s,
        role,
        screen.status_rect.row,
        screen.status_rect.cols,
      ]
    end

    def input_field_state(field)
      [
        field.prompt_text.to_s,
        field.buffer.text.to_s,
        field.buffer.cursor,
        field.buffer.virtual_suffix.to_s,
        field.buffer.region_active?,
        field.buffer.region_range,
        screen.input_rect.row,
        screen.input_rect.cols,
      ]
    end

    def popup_state(session)
      [
        popup_border,
        session.displayed.map(&:to_s),
        session.selected,
        session.field.buffer.text.to_s,
        session.field.cursor_x,
        session.selected_labels.sort,
        session.counts,
      ]
    end

    def popup_counts_text(session)
      counts = session.counts

      "#{counts[:total]} total · " \
      "#{counts[:selected]} selected · " \
      "#{counts[:matching]} matching · " \
      "#{counts[:showing]} showing"
    end

    def popup_border
      spec = popup_frame_spec

      border = (spec[:border] || spec["border"] || :single).to_sym
      corners = (spec[:corners] || spec["corners"] || :square).to_sym

      edge = FRAME_STYLES.fetch(border, FRAME_STYLES[:single])
      corner_set = CORNER_STYLES.fetch(corners, CORNER_STYLES[:square])
      corner =
        corner_set[border] ||
        corner_set[:single] ||
        CORNER_STYLES[:square][border] ||
        CORNER_STYLES[:square][:single]

      {
        h: edge[:h],
        v: edge[:v],
        tl: corner[:tl],
        tr: corner[:tr],
        bl: corner[:bl],
        br: corner[:br],
      }
    end

    def popup_frame_spec
      palette[:popup_frame] || {}
    rescue StandardError => e
      Fatty.warn("Could not resolve popup frame style: #{e.class}: #{e.message}", tag: :theme)
      {}
    end

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

    def normalized_highlights(highlights)
      return if highlights.nil?

      highlights.each_with_object({}) do |(line_no, ranges), out|
        out[line_no] =
          Array(ranges).map do |r|
          if r.is_a?(Hash)
            [r[:from].to_i, r[:to].to_i, (r[:role] || :primary).to_sym]
          else
            [r[0].to_i, r[1].to_i, (r[2] || :primary).to_sym]
          end
        end
      end
    end

    def highlight_ranges_for_line(highlights, abs_line)
      return [] unless highlights

      raw = highlights[abs_line]
      return [] unless raw

      # Accept any of:
      #   [[from,to], ...]
      #   [[from,to,:primary], [from,to,:secondary], ...]
      #   [{from:, to:, role:}, ...]
      ranges =
        Array(raw).map do |r|
        if r.is_a?(Hash)
          [r[:from].to_i, r[:to].to_i, (r[:role] || :primary).to_sym]
        else
          a = r[0].to_i
          b = r[1].to_i
          role = (r[2] || :primary).to_sym
          [a, b, role]
        end
      end

      ranges.sort_by!(&:first)
      ranges
    end

    def sync_backgrounds!
      nil
    end
  end
end

require_relative 'renderer/curses.rb'
require_relative 'renderer/truecolor.rb'
