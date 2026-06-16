SimpleCov.start do
  track_files "lib/**/*.rb"

  # any custom configs like groups and filters can be here at a central place
  add_filter %r{^/spec/}
  add_filter %r{^/bin/}
  add_filter %r{^/doc/}
  add_filter %r{^/sig/}
  add_filter %r{^/coverage/}
  add_filter %r{^/\.yardoc/}
  add_filter %r{^/\.ruby-lsp/}
  add_filter %r{^/\.git/}
  add_filter %r{^/\.githib/}
  add_filter %r{^/lib/fatty/config_files/}

  add_group "Core", %r{^/lib/fatty/[^/]*\.rb}
  add_group "Ansi", %r{^/lib/fatty/ansi/.*\.rb}
  add_group "Api", %r{^/lib/fatty/api/.*\.rb}
  add_group "Colors", %r{^/lib/fatty/colors/.*\.rb}
  add_group "Curses", %r{^/lib/fatty/curses/.*\.rb}
  add_group "History", %r{^/lib/fatty/history/.*\.rb}
  add_group "Logger", %r{^/lib/fatty/logger/.*\.rb}
  add_group "Markdown", %r{^/lib/fatty/markdown/.*\.rb}
  add_group "Renderer", %r{^/lib/fatty/renderer/.*\.rb}
  add_group "Sessions", %r{^/lib/fatty/session/.*\.rb}
  add_group "Terminal", %r{^/lib/fatty/terminal/.*\.rb}
  add_group "Themes", %r{^/lib/fatty/themes/.*\.rb}
  merge_timeout 3600
  # Make this true to merge rspec and cucumber coverage together
  use_merging false
  # enable_coverage :branch
end
