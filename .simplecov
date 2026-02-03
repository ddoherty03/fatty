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

  add_group "Core", %r{^/lib/fat_term/[^/]*\.rb}
  add_group "Views", %r{^/lib/fat_term/view/[^/]*\.rb}
  add_group "Sessions", %r{^/lib/fat_term/session/[^/]*\.rb}
  add_group "Curses", %r{^/lib/fat_term/backends/curses/[^/]*\.rb}
  merge_timeout 3600
  # Make this true to merge rspec and cucumber coverage together
  use_merging false
  # enable_coverage :branch
end
