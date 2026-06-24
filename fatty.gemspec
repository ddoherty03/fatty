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

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ddoherty03/fatty"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "CHANGELOG.org",
      "LICENSE.txt",
      "README.md",
      "README.org",
      "exe/*",
      "lib/**/*",
    ].select { |path| File.file?(path) }.sort
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "curses", "~> 1.4"
  spec.add_dependency "fat_config", ">=0.8.0"
  spec.add_dependency "rainbow"
  spec.add_dependency "redcarpet"
  spec.add_dependency "rouge"
  spec.add_dependency "unicode-display_width", "~> 2.5"
  spec.add_dependency "yaml"
end
