# frozen_string_literal: true

using Fatty::CoreExt::Hash

module Fatty
  module Config
    class << self
      attr_reader :progname, :app_name, :app_config_dir
      attr_accessor :reader
    end
    @progname = 'fatty'
    @config = {}
    @reader = nil
    @dir = nil

    # Read in the general configuration for fatty for certain user-adjustable
    # features of fatty in the per-user config.yml with the per-app config.yml
    # merged.  One of the config value sets up logging, including the location
    # of the log file.
    def self.config
      @config = read_layered("config")
    end

    # Read in the keydefs.yml config file that maps numeric keycodes returned
    # by curses but not assigned a key name.  This merges in the per-app
    # keydefs.yml as well.
    def self.keydefs
      read_layered("keydefs")
    end

    # Read in the keybindings.yml config file that maps key names (together
    # with any modifiers, shift, ctrl, meta) to action names to be triggered
    # by the key chord. This merges in the per-app keybindings.yml as well.
    def self.keybindings
      base = Array(global_reader.read("keybindings")[:keybindings])
      overlay = Array(read_app("keybindings"))
      base + overlay
    end

    def self.install_defaults!
      FileUtils.mkdir_p(user_config_dir)

      Dir.glob(File.join(dist_config_dir, "*")).each do |src|
        next unless File.file?(src)

        dst = File.join(user_config_dir, File.basename(src))
        Fatty.info("Copying config file #{src} to #{dst}", tag: :config)
        FileUtils.cp(src, dst) unless File.exist?(dst)
      end

      install_default_themes!
      nil
    end

    def self.install_default_themes!
      FileUtils.mkdir_p(user_themes_dir)

      Dir.glob(File.join(dist_themes_dir, "*.yml")).each do |src|
        dst = File.join(user_themes_dir, File.basename(src))
        unless File.exist?(dst)
          Fatty.info("Copying theme file #{src} to #{dst}", tag: :theme)
          FileUtils.cp(src, dst)
        end
      end
      nil
    end

    ###########################################################################
    # Accessors
    ###########################################################################

    # The name used for 'fatty' in forming directories such as
    # ~/.config/<progname>
    def self.progname=(name)
      @progname = name || 'fatty'
      reset_reader!
    end

    # The directory for user's fatty configuration, by default ~/.config/fatty
    def self.dir
      @dir
    end

    # And its setter
    def self.dir=(path)
      @dir = path
      reset_reader!
    end

    # Invoke both app-specific setters.
    def self.configure_app(app_name: nil, app_config_dir: nil)
      self.app_name = app_name
      self.app_config_dir = app_config_dir
      nil
    end

    # The name used by the consuming application to add app-specific
    # configuration.  If you use fatty for 10 different REPL-like apps, they
    # can each have independent configuration on top of fatty's global the
    # user configuration.
    def self.app_name=(name)
      @app_name = normalize_app_name(name)
      reset_reader!
    end

    # By default, the per-app configuration lives in
    # ~/.config/fatty/apps/<app_name>/ but the consuming app may want fatty's
    # config to live in its own config directory.  This allows the per-app
    # config directory to be placed elsewhere.
    def self.app_config_dir=(path)
      @app_config_dir = path && File.expand_path(path)
      reset_reader!
    end

    # The per-user config pathname, normally ~/.config/fatty/config.yml
    def self.user_config_path
      @reader ||= FatConfig::Reader.new(progname, user_dir: user_config_dir)
      reader.config_paths[:user].first || default_user_path('config')
    end

    # The per-user config directory, which falls back to XDG conventions if
    # dir is not set.
    def self.user_config_dir
      dir || File.join(
        ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
        progname,
      )
    end

    # The per-user themes directory, installed below the config directory.
    def self.user_themes_dir
      File.join(user_config_dir, "themes")
    end

    # The per-app config directory, either under ~/.config/fatty/apps/<app_name> (by
    # default) or the directory the library consumer sets in app_config_dir.
    def self.app_user_config_dir
      if app_config_dir
        app_config_dir
      elsif app_name
        File.join(user_config_dir, "apps", app_name)
      end
    end

    def self.app_config_path(name = "config")
      return unless app_user_config_dir

      File.join(app_user_config_dir, "#{name}.yml")
    end

    # The per-app themes directory, either under
    # ~/.config/fatty/apps/<app_name>/themes (by default) or under the themes
    # directory in the config directory the library consumer sets in
    # app_config_dir.
    def self.app_themes_dir
      return unless app_user_config_dir

      File.join(app_user_config_dir, "themes")
    end

    # The per-user keydefs path name, normally ~/.config/fatty/keydefs.yml
    def self.user_keydefs_path
      @reader ||= FatConfig::Reader.new(progname, user_dir: user_config_dir)
      reader.config_paths("keydefs")[:user].first || default_user_path("keydefs")
    end

    # The per-user keybindings path name, normally ~/.config/fatty/keybindings.yml
    def self.user_keybindings_path
      self.reader ||= FatConfig::Reader.new(progname, user_dir: user_config_dir)
      reader.config_paths("keybindings")[:user].first || default_user_path("keybindings")
    end

    # The default per-user config pathname for any of the config files, normally
    # ~/.config/fatty/config.yml, ~/.config/fatty/keydefs.yml, etc.
    def self.default_user_path(name = 'config')
      "~/.config/#{progname}/#{name}.yml"
    end

    # The directory where the fatty gem stores the distributed sample config
    # and theme files.
    def self.dist_config_dir
      File.expand_path("config_files", __dir__)
    end

    # The directory where the fatty gem stores the distributed distributed theme
    # files.
    def self.dist_themes_dir
      File.join(dist_config_dir, "themes")
    end

    ###########################################################################
    # Helpers
    ###########################################################################

    def self.reset_reader!
      @reader = nil
      @config = {}
    end

    def self.global_reader
      @reader ||= FatConfig::Reader.new(progname, user_dir: user_config_dir)
    end

    def self.reader_for_dir(path)
      FatConfig::Reader.new(progname, user_dir: path)
    end

    def self.read_layered(name)
      base = global_reader.read(name)
      overlay = read_app(name)
      merge_config(base, overlay)
    end

    def self.read_app(name)
      path = app_config_path(name)
      return {} unless path
      return {} unless File.exist?(path)

      YAML.load_file(path, symbolize_names: true) || {}
    end

    def self.merge_config(base, overlay)
      return normalize_config_value(overlay) if blank_config?(base)
      return normalize_config_value(base) if blank_config?(overlay)

      if base.is_a?(Hash) && overlay.is_a?(Hash)
        base.deep_merge(overlay)
      elsif base.is_a?(Array) && overlay.is_a?(Array)
        base + overlay
      else
        overlay
      end
    end

    def self.merge_keybindings(base, overlay)
      return normalize_config_value(overlay) if blank_config?(base)
      return normalize_config_value(base) if blank_config?(overlay)

      if base.is_a?(Hash) && overlay.is_a?(Hash)
        merged = base.deep_merge(overlay)
        merged[:keybindings] =
          Array(base[:keybindings]) + Array(overlay[:keybindings])
        merged
      elsif base.is_a?(Array) && overlay.is_a?(Array)
        base + overlay
      else
        overlay
      end
    end

    def self.blank_config?(value)
      value.nil? || value == {} || value == []
    end

    def self.normalize_config_value(value)
      value || {}
    end

    def self.normalize_app_name(name)
      text = name.to_s.strip
      text.empty? ? nil : text
    end

    private_class_method :reset_reader!
    private_class_method :global_reader
    private_class_method :reader_for_dir
    private_class_method :read_layered
    private_class_method :read_app
    private_class_method :merge_config
    private_class_method :blank_config?
    private_class_method :normalize_config_value
    private_class_method :normalize_app_name
  end
end
