# frozen_string_literal: true

module FatTerm
  module Config
    # Read in the general configuration for fat_term in config.yml for certain
    # user-adjustable features of fat_term.  One of these is the logging,
    # including the location of the log file.
    def self.config
      FatConfig::Reader.new('fat_term').read('config')
    rescue FatConfig::ParseError => ex
      begin
        FatConfig::Reader.new("fat_term").read("config", verbose: true)
      rescue StandardError
        # ignore secondary failure; we only wanted diagnostic output
      end
      raise ex
    end

    # Read in the keydefs.yml config file that maps numeric keycodes returned
    # by curses but not assigned a key name.
    def self.keydefs
      FatConfig::Reader.new('fat_term').read('keydefs')
    rescue FatConfig::ParseError => ex
      begin
        FatConfig::Reader.new('fat_term').read('keydefs', verbose: true)
      rescue StandardError
        # ignore secondary failure; we only wanted diagnostic output
      end
      raise ex
    end

    # Read in the keybindings.yml config file that maps key names (together
    # with any modifiers, shift, ctrl, meta) to action names to be triggered
    # by the key chord.
    def self.keybindings
      kb_cfg = FatConfig::Reader.new("fat_term").read("keybindings")
      return [] unless kb_cfg.is_a?(Hash)

      bindings = kb_cfg[:keybindings]
      Array(bindings)
    rescue FatConfig::ParseError => ex
      begin
        FatConfig::Reader.new("fat_term").read("keybindings", verbose: true)
      rescue StandardError
        # ignore secondary failure; we only wanted diagnostic output
      end
      raise ex
    end
  end
end
