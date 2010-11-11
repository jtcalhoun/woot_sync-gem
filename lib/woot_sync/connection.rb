require 'mechanize'

module WootSync
  class ConnectionError < WootSyncException; end

  module Connection
    extend ActiveSupport::Concern

    included do
      config_accessor :site_host
      config_accessor :user_agent

      def config.user_agent=(string)
        unless string.blank?
          parts  = {'lib' => "WootSync/#{WootSync::VERSION::STRING}", 'host' => site_host}
          string = (RUBY_VERSION >= '1.9') ? string % parts : begin
            string.gsub(/%\{([^\}]+)\}/, '%s') % string.scan(/%\{([^\}]+)\}/).flatten.map { |k| parts[k] }
          end

          Mechanize::AGENT_ALIASES.merge!({'WootSync' => string})
        end

        super
      end
    end

    module ClassMethods

      delegate :delete, :get, :get_file, :head, :post, :put, :to => :connection

      def connection
        @@connection ||= Mechanize.new do |agent|
          agent.log              = WootSync::Base.logger
          agent.max_history      = 0
          agent.user_agent_alias = 'WootSync'
        end
      end
    end
  end
end
