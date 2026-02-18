# frozen_string_literal: true

require 'yaml'
require 'fat_config'
require 'debug'

# Gem Overview (extracted from README.org by gem_docs)
#
# * Introduction
#
module FatTerm
  require_relative "fat_term/version"
  require_relative "fat_term/env"
  require_relative "fat_term/config"
  require_relative "fat_term/logger"
  require_relative "fat_term/action_environment"
  require_relative "fat_term/action"
  require_relative "fat_term/actionable"
  require_relative "fat_term/history"
  require_relative "fat_term/input_buffer"
  require_relative "fat_term/input_field"
  require_relative "fat_term/output_buffer"
  require_relative "fat_term/pager"
  require_relative "fat_term/alert"
  require_relative "fat_term/key_event"
  require_relative "fat_term/key_map"
  require_relative "fat_term/ansi"
  require_relative "fat_term/colors"
  require_relative "fat_term/backends/curses/curses_coder"
  require_relative "fat_term/backends/curses/renderer"
  require_relative "fat_term/backends/curses/key_decoder"
  require_relative "fat_term/backends/curses/event_source"
  require_relative "fat_term/backends/curses/context"
  require_relative "fat_term/prompt"
  require_relative "fat_term/screen"
  require_relative "fat_term/viewport"
  require_relative "fat_term/views"
  require_relative "fat_term/sessions"
  require_relative "fat_term/terminal"

  class Error < StandardError; end
end
