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
          input: { fg: "white", bg: "default" },
          input_suggestion: { fg: "lightgray", bg: "default" },
          cursor: { fg: "black", bg: "yellow" },

          region: { fg: "navy", bg: "yellow" },

          status_info: { fg: "black", bg: "lightgray" },
          status_warn: { fg: "black", bg: "magenta" },
          status_error: { fg: "white", bg: "red" },

          pager_status: {fg: "black", bg: "lightgreen"},

          search_highlight: { fg: "black", bg: "yellow" },
          search_highlight_secondary: { fg: "black", bg: "lightgray" },
          search: { fg: "black", bg: "cyan" },

          popup: { fg: "white", bg: "navy" },
          popup_selection: { fg: "navy",   bg: 'yellow' },
          popup_input: { fg: "white",  bg: "dark_blue" },
          popup_frame: { fg: "white",  bg: "navy" },
        },

        nordic: {
          output: { fg: "#d8dee9", bg: "#2e3440" },
          input:  { fg: "#eceff4", bg: "#3b4252" },
          input_suggestion: { fg: "#81a1c1", bg: "#3b4252" },
          cursor: { fg: "#2e3440", bg: "#88c0d0" },

          region: { fg: "#2e3440", bg: "#88c0d0" },

          status_info:  { fg: "#2e3440", bg: "#88c0d0" },
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

          status_info:  { fg: "#002b36", bg: "#268bd2" },
          status_warn:  { fg: "#002b36", bg: "#cb4b16" },
          status_error: { fg: "#fdf6e3", bg: "#dc322f" },

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
          output: { fg: "default", bg: "default" },
          input: { fg: "default", bg: "default" },
          input_suggestion: { fg: "default", bg: "default" },
          cursor: { fg: "default", bg: "default" },

          region: { fg: "default", bg: "default" },

          search_highlight: { fg: "black", bg: "yellow" },
          search_highlight_secondary: { fg: "black", bg: "lightgray" },
          search: { fg: "black", bg: "cyan" },

          pager_status: {fg: "black", bg: "lightgreen"},

          status_info: { fg: "default", bg: "default" },
          status_warn: { fg: "default", bg: "default" },
          status_error: { fg: "default", bg: "default" },

          popup: { fg: "default", bg: "default" },
          popup_selection: { fg: "default", bg: "default" },
          popup_input: { fg: "default", bg: "default" },
          popup_frame: { fg: "default", bg: "default" },
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
