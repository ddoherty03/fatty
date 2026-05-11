# frozen_string_literal: true

module Fatty
  module Curses
    module WindowStyling
      ATTR_FLAGS = {
        bold: ::Curses::A_BOLD,
        dim: ::Curses::A_DIM,
        reverse: ::Curses::A_REVERSE,
        underline: ::Curses::A_UNDERLINE,
      }.freeze

      def pair_attr(role, fallback:)
        palette = context.palette
        spec = palette&.[](role)
        return fallback unless spec && spec[:pair]

        attr = ::Curses.color_pair(spec[:pair])

        Array(spec[:attrs]).each do |a|
          attr |= attr_flag(a)
        end

        attr
      end

      def attr_flag(name)
        ATTR_FLAGS.fetch(name.to_sym, 0)
      end
    end
  end
end
