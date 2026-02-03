# frozen_string_literal: true

# spec/spec_helper.rb
require "simplecov"

SimpleCov.nocov_token 'no_cover'
SimpleCov.start do
  enable_coverage :branch
  track_files "lib/**/*.rb"

  add_filter "/spec/"
  add_filter "/vendor/"
  add_filter "/bin/"

  add_group "Models", "lib/fat_term/(action|actionable|alert|config|history|input|output|viewport|key_|log)"
end
# SimpleCov.start

# SimpleCov.start do
#   enable_coverage :branch

#   track_files "lib/**/*.rb"

#   add_filter "/spec/"
#   add_filter "/vendor/"
#   add_filter "/bin/"

#   add_group "Sessions", "lib/fat_term/session"
#   add_group "Views",    "lib/fat_term/view"
#   add_group "Models",   "lib/fat_term/(alert|history|input|output|viewport|keymap)"
#   add_group "Renderer", "lib/fat_term/renderer"
#   add_group "Core",     "lib/fat_term/(terminal|event|command|screen)"
# end

require "bundler/setup"
require "fat_term"
require "debug"

require "fat_term"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed
end
