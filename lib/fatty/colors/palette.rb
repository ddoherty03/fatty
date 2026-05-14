# frozen_string_literal: true

module Fatty
  module Colors
    # Palette compiles a resolved symbolic theme_spec into a renderer-ready
    # palette.
    #
    # A theme_spec is produced by Fatty::Themes::Resolver. It maps role names
    # to symbolic color specifications, usually color names and attributes:
    #
    # #+begin_src ruby
    #   {
    #     output: { fg: "white", bg: "navy" },
    #     alert_warn: { fg: "yellow", bg: "pink", attrs: [:bold] },
    #   }
    # #+end_src
    #
    # A palette maps those same role names to concrete rendering data:
    #
    # #+begin_src ruby
    #   {
    #     output: {
    #       fg: 7,
    #       bg: 4,
    #       fg_rgb: [255, 255, 255],
    #       bg_rgb: [0, 0, 128],
    #       pair: 1,
    #       attrs: [],
    #     },
    #   }
    # #+end_src
    #
    # Curses renderers use :pair and :attrs. Truecolor renderers use
    # :fg_rgb, :bg_rgb, and :attrs.
    #
    # - .build :: returns the compiled palette without touching curses.
    # - .apply! :: also initializes curses color pairs.
    #
    module Palette
      DEFAULT_ROLE = { fg: "default", bg: "default" }.freeze

      # Compile a theme_spec into a renderer-ready palette without initializing
      # curses color pairs.
      def self.compile(theme_spec, available_colors:)
        palette = {}

        Pairs::ROLE_TO_PAIR.each do |role, pair_id|
          role_spec = theme_spec.fetch(role, DEFAULT_ROLE)

          fg_spec = role_spec[:fg] || DEFAULT_ROLE[:fg]
          bg_spec = role_spec[:bg] || DEFAULT_ROLE[:bg]

          fg = Fatty::Color.resolve(fg_spec, available_colors: available_colors)
          bg = Fatty::Color.resolve(bg_spec, available_colors: available_colors)
          attrs = Array(role_spec[:attrs] || role_spec["attrs"]).map(&:to_sym)
          fg_rgb = Fatty::Color.rgb(fg_spec)
          bg_rgb = Fatty::Color.rgb(bg_spec)

          palette[role] = {
            fg: fg,
            bg: bg,
            fg_rgb: fg_rgb,
            bg_rgb: bg_rgb,
            pair: pair_id,
            attrs: attrs,
          }
        end
        palette
      end
    end
  end
end
