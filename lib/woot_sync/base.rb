#--
#  base.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-10-30.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

require 'active_support/configurable'

module WootSync
  class Base
    include ActiveSupport::Configurable
    config_accessor :logger, :user_agent
  end

  Base.class_eval do
    include Connection
    include Shops
  end
end
