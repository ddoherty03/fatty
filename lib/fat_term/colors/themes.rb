# lib/fat_term/colors/themes.rb
# frozen_string_literal: true

module FatTerm
  module Colors
    module Themes
      # Theme values may be:
      # - ANSI names (e.g., "yellow", "bright_white")
      # - Aliases supported by FatTerm::Color (e.g., "navy", "dark_blue")
      # - Integers 0..255
      # - Hex strings "#RRGGBB"
      # - X11 color names (if present in your bundled rgb.txt)
      #
      # Roles are intentionally scoped (popup_selection vs region, etc.)
      THEMES = {
        wordperfect: {
          output: { fg: "white", bg: "navy" },
          input: { fg: "white", bg: "navy" },
          input_suggestion: { fg: "lightgray", bg: "navy" },
          cursor: { fg: "white", bg: "red" },

          region: { fg: "navy", bg: "yellow" },

          status_good: { fg: "green", bg: "navy" },
          status_info: { fg: "white", bg: "navy" },
          status_warn: { fg: "black", bg: "magenta" },
          status_error: { fg: "white", bg: "red" },

          pager_status: { fg: "black", bg: "lightgreen" },

          search_highlight: { fg: "black", bg: "red" },
          search_highlight_secondary: { fg: "grey", bg: "pink" },
          search: { fg: "black", bg: "cyan" },

          popup: { fg: "white", bg: "navy" },
          popup_selection: { fg: "navy",   bg: 'yellow' },
          popup_input: { fg: "white",  bg: "dark_blue" },
          popup_frame: { fg: "white",  bg: "navy" },
        },

        nordic: {
          output: { fg: "#d8dee9", bg: "#2e3440" },
          input: { fg: "#eceff4", bg: "#3b4252" },
          input_suggestion: { fg: "#81a1c1", bg: "#3b4252" },
          cursor: { fg: "#2e3440", bg: "#88c0d0" },

          region: { fg: "#2e3440", bg: "#88c0d0" },

          status_good: { fg: "green", bg: "#2e3440" },
          status_info: { fg: "#d8dee9", bg: "#2e3440" },
          status_warn:  { fg: "#2e3440", bg: "#ebcb8b" },
          status_error: { fg: "#eceff4", bg: "#bf616a" },

          pager_status: {fg: "black", bg: "lightgreen"},

          search_highlight: { fg: "black", bg: "yellow" },
          search_highlight_secondary: { fg: "black", bg: "lightgray" },
          search: { fg: "black", bg: "cyan" },

          popup:           { fg: "#d8dee9", bg: "#3b4252" },
          popup_selection: { fg: "#2e3440", bg: "#88c0d0" },
          popup_input:     { fg: "#eceff4", bg: "#434c5e" },
          popup_frame:     { fg: "#81a1c1", bg: "#3b4252" },
        },

        solarized_dark: {
          output: { fg: "#839496", bg: "#002b36" },
          input:  { fg: "#93a1a1", bg: "#073642" },
          input_suggestion: { fg: "#657b83", bg: "#073642" },
          cursor: { fg: "#002b36", bg: "#b58900" },

          region: { fg: "#002b36", bg: "#b58900" },

          status_good: { fg: "green", bg: "#002b36" },
          status_info: { fg: "#839496", bg: "#002b36" },
          status_warn:  { fg: "#002b36", bg: "#cb4b16" },
          status_error: { fg: "#fdf6e3", bg: "red" },

          pager_status: {fg: "black", bg: "lightgreen"},

          search_highlight: { fg: "black", bg: "yellow" },
          search_highlight_secondary: { fg: "black", bg: "lightgray" },
          search: { fg: "black", bg: "cyan" },

          popup:           { fg: "#839496", bg: "#073642" },
          popup_selection: { fg: "#002b36", bg: "#b58900" },
          popup_input:     { fg: "#93a1a1", bg: "#002b36" },
          popup_frame:     { fg: "#268bd2", bg: "#073642" },
        },

        mono: {
          output: { fg: "black", bg: "white" },
          input: { fg: "white", bg: "black" },
          input_suggestion: { fg: "gray", bg: "white" },
          cursor: { fg: "black", bg: "white" },

          region: { fg: "black", bg: "white" },

          search_highlight: { fg: "black", bg: "yellow" },
          search_highlight_secondary: { fg: "black", bg: "lightgray" },
          search: { fg: "black", bg: "cyan" },

          pager_status: {fg: "black", bg: "white"},

          status_good: { fg: "green", bg: "white" },
          status_info: { fg: "black", bg: "white" },
          status_warn: { fg: "default", bg: "default" },
          status_error: { fg: "default", bg: "default" },

          popup: { fg: "black", bg: "white" },
          popup_selection: { fg: "white", bg: "black" },
          popup_input: { fg: "white", bg: "black" },
          popup_frame: { fg: "black", bg: "white" },
        },
      }.freeze

      def self.fetch(name)
        return if name.nil?

        THEMES[name.to_sym]
      end

      def self.names
        THEMES.keys
      end
    end
  end
end
