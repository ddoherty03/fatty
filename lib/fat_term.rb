# frozen_string_literal: true

require 'yaml'
require 'fat_config'

# Gem Overview (extracted from README.org by gem_docs)
#
# * Introduction
module FatTerm
  require_relative "fat_term/version"
  require_relative "fat_term/env"
  require_relative "fat_term/config"
  require_relative "fat_term/history"
  require_relative "fat_term/input_buffer"
  require_relative "fat_term/input_field"
  require_relative "fat_term/output_buffer"
  require_relative "fat_term/alert"
  require_relative "fat_term/alert_panel"
  require_relative "fat_term/prompt"
  require_relative "fat_term/renderer"
  require_relative "fat_term/key_decoder"
  require_relative "fat_term/screen"
  require_relative "fat_term/key_event"
  require_relative "fat_term/curses_coder"
  require_relative "fat_term/key_map"
  require_relative "fat_term/terminal"

  class Error < StandardError; end
end
