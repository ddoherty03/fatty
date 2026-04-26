# frozen_string_literal: true

module Fatty
  module Config
    class << self
      attr_reader :progname
      attr_accessor :reader
      attr_accessor :dir
    end
    @progname = 'fat_term'
    @config = {}
    @reader = nil
    @dir = nil

    # Read in the general configuration for fat_term in config.yml for certain
    # user-adjustable features of fat_term.  One of these is the logging,
    # including the location of the log file.
    def self.config
      @reader ||= FatConfig::Reader.new(progname, user_dir: dir)
      @config = reader.read('config')
    end

    def self.progname=(name)
      @progname = name || 'fat_term'
      @reader = nil
    end

    def self.user_config_path
      @reader ||= FatConfig::Reader.new(progname, user_dir: dir)
      reader.config_paths[:user].first || default_user_path('config')
    end

    def self.user_keydefs_path
      @reader ||= FatConfig::Reader.new(progname)
      reader.config_paths('keydefs')[:user].first || default_user_path('keydefs')
    end

    def self.user_keybindings_path
      self.reader ||= FatConfig::Reader.new(progname)
      reader.config_paths('keybindings')[:user].first || default_user_path('keybindings')
    end

    # Read in the keydefs.yml config file that maps numeric keycodes returned
    # by curses but not assigned a key name.
    def self.keydefs
      FatConfig::Reader.new(progname).read('keydefs')
    end

    # Read in the keybindings.yml config file that maps key names (together
    # with any modifiers, shift, ctrl, meta) to action names to be triggered
    # by the key chord.
    def self.keybindings
      kb_cfg = FatConfig::Reader.new(progname).read("keybindings")
      return [] unless kb_cfg.is_a?(Hash)

      bindings = kb_cfg[:keybindings]
      Array(bindings)
    end

    def self.default_user_path(name = 'config')
      "~/.config/#{progname}/#{name}.yml"
    end
  end
end
