# frozen_string_literal: true

module FatTerm
  module Config
    # The @errors variable provides a way to accummulate error messages so
    # that they can be displayed to the user once the Terminal and Alert panel
    # are up and running, which is probably not the case when the configs are
    # being read in.

    # Return an Array of errors seen while reading in the config files.
    def self.errors
      @errors ||= []
    end

    # Clear the Array of errors.
    def self.clear_errors!
      errors.clear
    end

    # Read in the keydefs.yml config file that maps numeric keycodes returned
    # by curses but not assigned a key name.
    def self.keydefs
      FatConfig::Reader.new('fat_term').read('keydefs')
    rescue FatConfig::ParseError => ex
      record_error("keydefs", ex)
      {}
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
      record_error("keybindings", ex)
      []
    end

    # Read in the general configuration for fat_term in config.yml for certain
    # user-adjustable features of fat_term.  One of these is the logging,
    # including the location of the log file.
    def self.config
      FatConfig::Reader.new('fat_term').read('config')
    rescue FatConfig::ParseError => ex
      record_error("config", ex)
      {}
    end

    def self.record_error(file, ex)
      msg = "Config parse error in #{file}.yml: #{ex.message}"
      errors << { file: file, error: ex }

      FatTerm.log("config_parse_error", level: :error, tag: :config, file: "#{file}.yml", err: ex.class.name, msg: ex.message)
      msg
    end
  end
end
