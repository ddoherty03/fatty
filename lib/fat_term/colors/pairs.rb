# lib/fat_term/colors/pairs.rb
# frozen_string_literal: true

module FatTerm
  module Colors
    # Stable Curses color-pair IDs. These are intentionally constant so the
    # renderer can refer to them without dynamic allocation.
    #
    # Pair 0 is reserved in ncurses; start at 1.
    module Pairs
      OUTPUT           = 1
      INPUT            = 2
      INPUT_SUGGESTION = 8
      CURSOR           = 3
      REGION           = 4

      STATUS_INFO      = 5
      STATUS_WARN      = 6
      STATUS_ERROR     = 7
      STATUS_GOOD      = 8

      SEARCH = 10
      SEARCH_HIGHLIGHT = 11
      SEARCH_HIGHLIGHT_SECONDARY = 12
      PAGER_STATUS = 15

      POPUP           = 20
      POPUP_SELECTION = 21
      POPUP_INPUT     = 22
      POPUP_FRAME     = 23

      # Role -> pair id mapping for iteration.
      ROLE_TO_PAIR = {
        output: OUTPUT,
        input: INPUT,
        input_suggestion: INPUT_SUGGESTION,
        cursor: CURSOR,
        region: REGION,

        status_good: STATUS_GOOD,
        status_info: STATUS_INFO,
        status_warn: STATUS_WARN,
        status_error: STATUS_ERROR,

        search_highlight: SEARCH_HIGHLIGHT,
        search_highlight_secondary: SEARCH_HIGHLIGHT_SECONDARY,
        search: SEARCH,

        pager_status: PAGER_STATUS,

        popup: POPUP,
        popup_selection: POPUP_SELECTION,
        popup_input: POPUP_INPUT,
        popup_frame: POPUP_FRAME,
      }.freeze
    end
  end
end
