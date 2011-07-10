require 'active_support/core_ext/module/aliasing'

module WootSync
  module Railtie
    class << self

      ##
      # Sets configuration variables and values from a file
      # +config/settings.yml+ in the gem's root directory. Loads any OAuth
      # credentials from the +WOOT_SYNC_AUTH+ environment variable, if
      # provided.
      #
      # @param [Hash] hash an optional string-keyed Hash of config values
      # @return [ActiveSupport::InheritableOptions] the configuration hash
      # @example
      #   WootSync::Railtie.load_settings!({'var' => 'value'}) # => #<OrderedHash {:var => 'value', :shops => [{"woot" => ...}]}>
      #
      def load_settings!(hash = {})
        WootSync.configure do |config|
          settings = {}

          [
            File.expand_path('../../../config/settings.yml', __FILE__),
            File.join(Dir.home, '.wootsync'),
            File.join(Dir.pwd, '.wootsync')
          ].each do |file|
            begin
              settings.deep_merge!(YAML::load(IO.read(file)) || {})

            rescue Errno::ENOENT
              # Do nothing.
            end
          end

          settings.deep_merge!(hash)

          if settings.empty?
            warn 'WARNING: no WootSync configuration provided'
          else
            settings.each do |k,v|
              config.send("#{k}=", v)
            end
          end

          config.logger ||= begin
            require 'logger'
            Logger.new(STDOUT)
          end
        end

        return WootSync.config
      end

      if defined?(Rails::Railtie)
        def load_settings_with_rails!
          # Do nothing.
        end

        alias_method_chain :load_settings!, :rails

        class Railtie < Rails::Railtie
          config.woot_sync = ActiveSupport::OrderedOptions.new

          initializer 'woot_sync.load_settings' do |app|
            WootSync::Railtie.load_settings_without_rails!(app.config.woot_sync)
          end

          initializer 'woot_sync.logger', :after => 'woot_sync.load_settings' do
            WootSync.logger = Rails.logger
          end
        end
      end
    end
  end
end
