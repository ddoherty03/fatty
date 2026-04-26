# frozen_string_literal: true

module FatTerm
  # Screen is a backend-neutral layout model.
  #
  # It describes terminal geometry (rows/cols) and the logical regions that
  # FatTerm draws into (output/input/alert). Screen does not perform any IO
  # and does not depend on curses.
  #
  # Curses uses Screen to allocate resources (windows) and to understand where
  # drawing should occur.
  class Screen
    Rect = Struct.new(:row, :col, :rows, :cols, keyword_init: true) do
      def bottom
        row + rows
      end

      def right
        col + cols
      end
    end

    attr_reader :rows, :cols
    attr_reader :output_rect
    attr_reader :input_rect
    attr_reader :alert_rect
    attr_reader :status_rect

    def initialize(rows:, cols:, status_rows: 0)
      resize(rows: rows, cols: cols, status_rows: status_rows)
    end

    # Update the terminal geometry and recompute the layout.
    def resize(rows:, cols:, status_rows: 0)
      @rows = rows
      @cols = cols
      layout!(status_rows: status_rows)
      self
    end

    # --- Regions ----------------------------------------------------------

    private

    # Default layout:
    # - status: 1 row above input (when it has content)
    # - input:  1 row above alert
    # - alert:  1 bottom row
    # - output: all remaining rows
    #
    # If the terminal is too small, clamp to non-negative sizes.
    def layout!(status_rows: 0)
      status_rows = status_rows.to_i
      status_rows = 0 if status_rows.negative?

      alert_rows = rows >= 1 ? 1 : 0
      input_rows = rows >= 2 ? 1 : 0
      status_rows = 0 if rows < 3

      alert_row = rows - alert_rows
      input_row = alert_row - input_rows
      status_row = input_row - status_rows

      @alert_rect = Rect.new(
        row: [alert_row, 0].max,
        col: 0,
        rows: alert_rows,
        cols: cols,
      )

      @input_rect = Rect.new(
        row: [input_row, 0].max,
        col: 0,
        rows: input_rows,
        cols: cols,
      )

      @status_rect = Rect.new(
        row: [status_row, 0].max,
        col: 0,
        rows: status_rows,
        cols: cols,
      )

      output_rows = status_row
      output_rows = 0 if output_rows.negative?

      @output_rect = Rect.new(
        row: 0,
        col: 0,
        rows: output_rows,
        cols: cols,
      )
    end
  end
end
