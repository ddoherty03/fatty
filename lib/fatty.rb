# frozen_string_literal: true

require 'yaml'
require 'fat_config'
require "json"
require "time"
require "fileutils"
require "rainbow"

require 'debug'

# Gem Overview (extracted from README.org by gem_docs)
#
# * Introduction
#
module Fatty
  require_relative "fatty/version"
  require_relative "fatty/env"
  require_relative "fatty/config"
  require_relative "fatty/logger"
  require_relative "fatty/counter"
  require_relative "fatty/action_environment"
  require_relative "fatty/accept_env"
  require_relative "fatty/action"
  require_relative "fatty/actionable"
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
  require_relative "fatty/ansi"
  require_relative "fatty/colors"
  require_relative "fatty/curses"
  require_relative "fatty/prompt"
  require_relative "fatty/menu_env"
  require_relative "fatty/screen"
  require_relative "fatty/viewport"
  require_relative "fatty/views"
  require_relative "fatty/sessions"
  require_relative "fatty/terminal"

  class Error < StandardError; end
end
