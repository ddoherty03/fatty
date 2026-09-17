# -*- mode: ruby -*-

# frozen_string_literal: true

cover "lib/**/*.rb"

# any custom configs like groups and filters can be here at a central place
skip %r{^/spec/}
skip %r{^/bin/}
skip %r{^/doc/}
skip %r{^/sig/}
skip %r{^/coverage/}
skip %r{^/\.yardoc/}
skip %r{^/\.ruby-lsp/}
skip %r{^/\.git/}
skip %r{^/\.githib/}
skip %r{^/lib/fatty/config_files/}

group "Core", %r{^/lib/fatty/[^/]*\.rb}
group "Ansi", %r{^/lib/fatty/ansi/.*\.rb}
group "Api", %r{^/lib/fatty/api/.*\.rb}
group "Colors", %r{^/lib/fatty/colors/.*\.rb}
group "Curses", %r{^/lib/fatty/curses/.*\.rb}
group "History", %r{^/lib/fatty/history/.*\.rb}
group "Logger", %r{^/lib/fatty/logger/.*\.rb}
group "Markdown", %r{^/lib/fatty/markdown/.*\.rb}
group "Renderer", %r{^/lib/fatty/renderer/.*\.rb}
group "Sessions", %r{^/lib/fatty/session/.*\.rb}
group "Terminal", %r{^/lib/fatty/terminal/.*\.rb}
group "Themes", %r{^/lib/fatty/themes/.*\.rb}
merge_timeout 3600

# Make this true to merge rspec and cucumber coverage together
merging false
# enable_coverage :branch
