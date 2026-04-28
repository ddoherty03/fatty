# frozen_string_literal: true

require_relative "lib/fatty/version"

Gem::Specification.new do |spec|
  spec.name = "fatty"
  spec.version = Fatty::VERSION
  spec.authors = ["Daniel E. Doherty"]
  spec.email = ["ded@ddoherty.net"]

  spec.summary     = "Stateful terminal UI with editable input and scrollback"
  spec.description = <<~DESC
    fatty is a pure Ruby curses-backed terminal interaction library with editable single-line input, scrollable output, and
    programmable keybindings, inspired by modern shells like fish.
  DESC
  spec.homepage = "https://github.com/ddoherty03/fatty"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ddoherty03/fatty"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "curses", "~> 1.4"
  spec.add_dependency "fat_config", ">=0.8.0"
  spec.add_dependency "unicode-display_width", "~> 2.5"
  spec.add_dependency "yaml"
  spec.add_dependency "rainbow"
  spec.add_dependency "redcarpet"
  spec.add_dependency "rouge"
end
