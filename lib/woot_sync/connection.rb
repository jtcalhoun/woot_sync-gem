#--
#  connection.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-10-30.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

require 'mechanize'

module WootSync
  module Connection
    extend ActiveSupport::Concern

    included do
      def config.user_agent=(string)
        string = string % WootSync::VERSION::STRING

        Mechanize::AGENT_ALIASES.merge!({'WootSync' => string}) unless string.blank?

        super(string)
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
