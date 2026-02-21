# lib/fat_term/colors/pairs.rb
# frozen_string_literal: true

module FatTerm
  module Colors
    # Stable Curses color-pair IDs. These are intentionally constant so the
    # renderer can refer to them without dynamic allocation.
    #
    # Pair 0 is reserved in ncurses; start at 1.
    module Pairs
      OUTPUT          = 1
      INPUT           = 2
      CURSOR          = 3
      REGION          = 4

      STATUS_INFO     = 5
      STATUS_WARN     = 6
      STATUS_ERROR    = 7

      SEARCH_HIGHLIGHT = 8
      SEARCH           = 9

      POPUP           = 10
      POPUP_SELECTION = 11
      POPUP_INPUT     = 12
      POPUP_FRAME     = 13

      # Role -> pair id mapping for iteration.
      ROLE_TO_PAIR = {
        output:          OUTPUT,
        input:           INPUT,
        cursor:          CURSOR,
        region:          REGION,

        status_info:     STATUS_INFO,
        status_warn:     STATUS_WARN,
        status_error:    STATUS_ERROR,

        search_highlight: SEARCH_HIGHLIGHT,
        search:           SEARCH,

        popup:           POPUP,
        popup_selection: POPUP_SELECTION,
        popup_input:     POPUP_INPUT,
        popup_frame:     POPUP_FRAME,
      }.freeze
    end
  end
end
