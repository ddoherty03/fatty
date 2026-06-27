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

    attr_reader :screen, :palette, :context, :theme_version

    def initialize(screen:, palette:, context:)
      @screen = screen
      @palette = palette
      @context = context
      @last_status_state = nil
      @last_alert_state = nil
      @last_output_state = nil
      @last_popup_state = nil
      @last_prompt_popup_state = nil
      @last_pager_field_state = nil
      @theme_version = 0
    end

    attr_writer :screen

    def apply_theme!(theme)
      Fatty::Themes::Manager.set(theme)
      @theme_version += 1
      theme_spec = Fatty::Themes::Manager.roles(Fatty::Themes::Manager.current) || {}
      @palette = Fatty::Colors::Palette.compile(theme_spec, available_colors: available_colors)

      after_apply_theme!
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

    def clear_input_field(...)
      raise NotImplementedError, "#{self.class} must implement #clear_input_field"
    end

    def restore_cursor(...)
      raise NotImplementedError, "#{self.class} must implement #restore_cursor"
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
      @last_prompt_popup_state = nil
    end

    def hide_cursor
    end

    def show_cursor
    end

    protected

    # simplecov:disable

    def alert_role(role)
      :"alert_#{role}"
    end

    def available_colors
      nil
    end

    def after_apply_theme!
      nil
    end

    def alert_state(session)
      session.state
    end

    def status_state(session)
      session.state
    end

    def popup_state(session)
      [
        popup_border,
        session.state
      ]
    end

    def prompt_popup_state(session)
      [
        popup_border,
        session.state
      ]
    end

    def output_state(session, viewport: session.viewport)
      session.state(viewport: viewport)
    end

    def input_field_state(input_field)
      [
        input_field.state,
        theme_version
      ]
    end

    def pager_field_state(field, row:, role:)
      [
        input_field_state(field),
        row,
        role,
        screen.output_rect.row,
        screen.output_rect.rows,
        screen.output_rect.cols,
      ].freeze
    end

    def renderable_text(value)
      renderable_parts(value).map { |part|
        if part.is_a?(Hash) && part.key?(:text)
          part[:text].to_s
        else
          part.to_s
        end
      }.join
    end

    def status_segment_lines(status_session)
      segments = renderable_segments(
        status_session.text,
        role: status_session.role,
      )
      segment_lines(segments, width: screen.status_rect.cols)
        .last(screen.status_rect.rows)
    end

    def segment_lines(segments, width:)
      lines = [[]]
      col = 0
      segments.each do |segment|
        text = segment[:text].to_s
        text.each_line do |raw|
          rest = raw.chomp
          until rest.empty?
            remaining = width - col
            if remaining <= 0
              lines << []
              col = 0
              remaining = width
            end
            piece = Fatty::Ansi.truncate_visible(rest, remaining)
            break if piece.empty?

            lines.last << segment.merge(text: piece)
            col += Fatty::Ansi.visible_length(piece)
            rest = rest[piece.length..].to_s
          end
          if raw.end_with?("\n")
            lines << []
            col = 0
          end
        end
      end
      lines
    end

    def wrap_status_line(line, width:)
      text = Fatty::Ansi.strip(line.to_s)
      return [""] if text.empty?

      chunks = []
      rest = text.dup

      until rest.empty?
        chunk = Fatty::Ansi.truncate_visible(rest, width)
        chunks << chunk
        rest = rest[chunk.length..].to_s
      end

      chunks
    end

    def renderable_segments(value, role:)
      renderable_parts(value).map do |part|
        if part.is_a?(Hash) && part.key?(:text)
          {
            text: part[:text].to_s,
            role: part[:role] || role,
            style: part[:style],
          }.compact
        else
          {
            text: part.to_s,
            role: role,
          }
        end
      end
    end

    def renderable_parts(value)
      value.is_a?(Array) ? value : [value]
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

    def normalized_highlights_state(highlights)
      deep_state(highlights)
    end

    def deep_state(value)
      case value
      when Hash
        value.to_h { |key, val| [deep_state(key), deep_state(val)] }.freeze
      when Array
        value.map { |item| deep_state(item) }.freeze
      when String
        value.dup.freeze
      else
        value
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

    def field_segments(field, base_role:, suggestion_role: :input_suggestion, region_role: :region)
      buf = field.buffer
      text = buf.text.to_s
      segments =
        Fatty::Ansi.segment(field.prompt_text.to_s).map do |prompt_text, style|
        {
          text: prompt_text,
          role: base_role,
          style: style,
        }
      end

      region =
        if buf.respond_to?(:region_range)
          buf.region_range
        end

      if region && region.begin < region.end
        max = text.length
        s = region.begin.clamp(0, max)
        e = region.end.clamp(0, max)

        segments << { text: text[0...s].to_s, role: base_role }
        segments << { text: text[s...e].to_s, role: region_role }
        segments << { text: text[e..].to_s, role: base_role }
      else
        segments << { text: text, role: base_role }
      end

      suffix = buf.virtual_suffix.to_s
      segments << { text: suffix, role: suggestion_role } unless suffix.empty?

      segments.reject { |seg| seg[:text].empty? }
    end

    def sync_backgrounds!
      nil
    end
  end
end

require_relative 'renderer/curses.rb'
require_relative 'renderer/truecolor.rb'
