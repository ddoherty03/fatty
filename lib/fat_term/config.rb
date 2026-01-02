# frozen_string_literal: true

module FatTerm
  def self.config
    # FatConfig::Reader.new('fat_term').read('keydefs')
    YAML.load_file("/home/ded/.config/fat_term/keydefs.yml")
  end
end
