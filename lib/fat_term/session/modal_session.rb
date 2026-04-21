# frozen_string_literal: true

module FatTerm
  class ModalSession < Session
    attr_reader :win
    private attr_writer :win

    def close
      FatTerm.debug("#{self.class}#close: object_id=#{object_id}", tag: :session)
      old_win = win
      self.win = nil
      safely_close_window(old_win)
      nil
    end

    def handle_resize(terminal:)
      rebuild_windows!(terminal)
      []
    end

    def rebuild_windows!(terminal)
      old_win = win
      self.win = nil
      safely_close_window(old_win)

      cols = ::Curses.cols
      rows = ::Curses.lines
      width, height = geometry(cols: cols, rows: rows)
      x = (cols - width) / 2
      y = (rows - height) / 2
      self.win = ::Curses::Window.new(height, width, y, x)
      nil
    end

    def geometry(cols:, rows:)
      raise NotImplementedError, "#{self.class} must implement #geometry"
    end

    # Common helpers for computing geometry

    def max_width(cols:, margin:, min_width:)
      [cols - (margin * 2), min_width].max
    end

    def max_height(rows:, margin:, min_height:)
      [rows - (margin * 2), min_height].max
    end

    def clamp_width(width, max_width:, hard_max: nil)
      width = [width, max_width].min
      width = [width, hard_max].min if hard_max
      width
    end

    def clamp_height(height, max_height:, min_height:)
      height.clamp(min_height, max_height)
    end
  end
end
