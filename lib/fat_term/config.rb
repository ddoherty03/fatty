# frozen_string_literal: true

module FatTerm
  module Config
    def self.keydefs
      path = config_path('keydefs')
      return {} unless File.exist?(path)

      # FatConfig::Reader.new('fat_term').read('keydefs')
      YAML.load_file(path)
    end

    def self.keybindings
      path = config_path('keybindings')
      return [] unless File.exist?(path)

      YAML.load_file(path)
    end

    def self.config_path(name)
      File.join(
        ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config"),
        "fat_term",
        "#{name}.yml",
      )
    end
  end
end
