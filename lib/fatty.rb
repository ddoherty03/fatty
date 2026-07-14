# frozen_string_literal: true

require 'yaml'
require 'fat_config'
require "json"
require "time"
require "fileutils"
require "rainbow"
require "redcarpet"
require "strscan"

require 'debug'

# Gem Overview (extracted from README.org by gem_docs)
#
# * Introduction
# ~Fatty~ aims to provide a full-featured command-line environment that provides:
#
# 1. an editing command-line input,
# 2. a history facility,
# 3. command completion,
# 4. completion of partially-typed file path names,
# 5. output into a paging environment,
# 6. searching within the paged output,
# 7. issuing messages to a "status" area separate from the output pane,
# 8. binding keys to pre-defined actions,
# 9. defining unrecognized key-codes as named keys,
# 10. color themes that can be selected in real time,
# 11. a way to define new themes,
# 12. processes completed command-lines with a callback procedure of your
#     choosing,
# 13. several user-interface widgets such a selection popups, prompt for input, etc.,
# 14. a set of progress indicators you can use to display to the end user,
# 15. a way to render markdown to the output pane,
#
# In other words, fatty allows you to write a terminal-based REPL of your choosing but takes
# care of all the difficult parts.
#
# ~Fatty~ is written entirely in Ruby and was born from my frustrations at the
# limitations of libraries like ~readline~ and ~reline~.  It relies on ~curses~
# and ~truecolor~ for low-level rendering and is surprisingly snappy.
#
# ~Fatty~ is /not/ a terminal emulator but runs on top of one.
module Fatty
  require_relative "fatty/version"
  require_relative "fatty/core_ext"
  require_relative "fatty/env"
  require_relative "fatty/config"
  require_relative "fatty/logger"
  require_relative "fatty/counter"
  require_relative "fatty/action"
  require_relative "fatty/actionable"
  require_relative "fatty/command"
  require_relative "fatty/history"
  require_relative "fatty/search"
  require_relative "fatty/input_buffer"
  require_relative "fatty/input_field"
  require_relative "fatty/output_buffer"
  require_relative "fatty/pager"
  require_relative "fatty/alert"
  require_relative "fatty/key_event"
  require_relative "fatty/mouse_event"
  require_relative "fatty/key_map"
  require_relative "fatty/colors"
  require_relative "fatty/ansi"
  require_relative "fatty/curses"
  require_relative "fatty/renderer"
  require_relative "fatty/themes"
  require_relative "fatty/prompt"
  require_relative "fatty/progress"
  require_relative "fatty/screen"
  require_relative "fatty/viewport"
  require_relative "fatty/session"
  require_relative "fatty/api"
  require_relative "fatty/terminal"
  require_relative "fatty/markdown"
  require_relative "fatty/help"
  require_relative "fatty/action_environment"
  require_relative "fatty/callback_environment"

  class Error < StandardError; end
  class Interrupt < StandardError; end
end
