# frozen_string_literal: true

module FatTerm
  module Config
    def self.keydefs
      FatConfig::Reader.new('fat_term').read('keydefs')
    end

    def self.keybindings
      kb_cfg = FatConfig::Reader.new('fat_term').read('keybindings')
      if kb_cfg.key?(:keybindings)
        kb_cfg[:keybindings]
      else
        {}
      end
    end

    def self.config
      FatConfig::Reader.new('fat_term').read('config')
    end
  end
end
