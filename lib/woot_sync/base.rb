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
  end

  Base.class_eval do
    include Shops
  end
end
