#--
#  Copyright 2012 Taco Stadium LLC. All rights reserved.
#
#  All information contained herein, including documentation and any related
#  computer programs, is confidential, proprietary, and protected by trade
#  secret or copyright law. Use, reproduction, modification or transmission in
#  whole or in part in any form or by any means is prohibited without prior
#  written consent of Taco Stadium LLC.
#++

module WootSync
  module Rails
    class << self

      ##
      # Sets configuration values from files in the following locations and in
      # the order indicated:
      #   1. +config/settings.yml+ in the gem's root directory
      #   2. +.woot_sync+ in the user's home directory
      #   3. +.woot_sync+ in the current working directory
      #
      # Then loads any OAuth credentials from the +WOOT_SYNC_AUTH+ environment
      # variable, if provided.
      #
      # @param [Hash] hash an optional string-keyed Hash of config values
      # @return [ActiveSupport::InheritableOptions] the configuration hash
      # @example
      #   WootSync::Railtie.load_settings!({'var' => 'value'}) # => #<OrderedHash {:var => 'value', :shops => [{"woot" => ...}]}>
      def load_settings!(hash = {})
        WootSync.configure do |config|
          settings = {}

          [
            File.expand_path("../../../../config/settings.yml", __FILE__),
            File.join(Dir.home, ".woot_sync"),
            File.join(Dir.pwd, ".woot_sync")
          ].each do |file|
            begin
              settings.deep_merge!(YAML::load(IO.read(file)) || {})

            rescue Errno::ENOENT
              # Do nothing.
            end
          end

          if (env_credentials = ENV["WOOT_SYNC_AUTH"].to_s.split(":")).any?
            settings.deep_merge!({"client" => {"credentials" => env_credentials}})
          end

          settings.deep_merge!(hash)

          if settings.empty?
            warn "WARNING: no WootSync configuration provided"
          else
            settings.each do |k,v|
              config.send("#{k}=", v)
            end
          end

          config.logger ||= begin
            require "logger"
            Logger.new(STDOUT)
          end
        end

        return WootSync.config
      end
    end

    if defined?(::Rails)
      class Engine < ::Rails::Engine
        config.woot_sync = ActiveSupport::OrderedOptions.new

        initializer "woot_sync.load_settings" do |app|
          WootSync::Rails.load_settings!(app.config.woot_sync)
        end

        initializer "woot_sync.set_logger", :after => "woot_sync.load_settings" do
          WootSync.logger = ::Rails.logger
        end
      end
    else
      WootSync::Rails.load_settings!
    end
  end
end
