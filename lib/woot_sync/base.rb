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
    class << self
      delegate :logger, :logger=, :to => :config
    end

    include ActiveSupport::Configurable
  end

  Base.class_eval do
    include Connection
    include Shops
  end
end
