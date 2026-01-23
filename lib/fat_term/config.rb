# frozen_string_literal: true

module FatTerm
  module Config
    def self.keydefs
      FatConfig::Reader.new('fat_term').read('keydefs')
    end

    def self.keybindings
      FatConfig::Reader.new('fat_term').read('keybindings')[:keybindings]
    end
  end
end
