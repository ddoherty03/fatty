# frozen_string_literal: true

# spec/spec_helper.rb
# My config is in .simplecov
require "simplecov"

require "bundler/setup"
require "fatty"
require "debug"

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

def with_action_registry
  snapshot = Fatty::Actions.snapshot
  yield
ensure
  Fatty::Actions.restore(snapshot)
end

def without_registered_actions
  snapshot = Fatty::Actions.snapshot
  Fatty::Actions.reset!
  yield
ensure
  Fatty::Actions.restore(snapshot)
end
