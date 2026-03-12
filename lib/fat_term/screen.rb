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
      def bottom = row + rows
      def right  = col + cols
    end

    attr_reader :rows, :cols

    def initialize(rows:, cols:)
      resize(rows:, cols:)
    end

    # Update the terminal geometry and recompute the layout.
    def resize(rows:, cols:)
      @rows = Integer(rows)
      @cols = Integer(cols)
      layout!
      self
    end

    # --- Regions ----------------------------------------------------------

    def output_rect = @output_rect
    def input_rect  = @input_rect
    def alert_rect  = @alert_rect

    private

    # Default layout:
    # - output: all but last 2 rows
    # - input:  1 row above alert
    # - alert:  1 bottom row
    #
    # If the terminal is too small, clamp to non-negative sizes.
    def layout!
      output_rows = [rows - 2, 0].max

      @output_rect = Rect.new(row: 0, col: 0, rows: output_rows, cols: cols)

      @input_rect =
        Rect.new(
          row: [rows - 2, 0].max,
          col: 0,
          rows: rows >= 2 ? 1 : 0,
          cols: cols,
        )

      @alert_rect =
        Rect.new(
          row: [rows - 1, 0].max,
          col: 0,
          rows: rows >= 1 ? 1 : 0,
          cols: cols,
        )
    end
  end
end
