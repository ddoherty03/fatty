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

def key(key, text: nil, ctrl: false, meta: false, shift: false)
  Fatty::KeyEvent.new(key: key, text: text, ctrl: ctrl, meta: meta, shift: shift)
end

def update(session, action, **payload)
  session.update(Fatty::Command.session(session.id, action, **payload))
end

def apply_action(session, action, *args)
  session.send(:apply_action, action, args, event: nil)
end

def stub_curses_window(rows: 24, cols: 80)
  win = instance_double(
    ::Curses::Window,
    erase: nil,
    noutrefresh: nil,
    close: nil,
  )

  allow(::Curses).to receive(:lines).and_return(rows)
  allow(::Curses).to receive(:cols).and_return(cols)
  allow(::Curses::Window).to receive(:new).and_return(win)

  win
end
