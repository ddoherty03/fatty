# frozen_string_literal: true

module Curses
  class Window
    def origin
      [begy, begx]
    end
  end
end

require_relative "curses/patch"
require_relative "curses/curses_coder"
require_relative "curses/key_decoder"
require_relative "curses/event_source"
require_relative "curses/context"
require_relative "curses/window_styling"
