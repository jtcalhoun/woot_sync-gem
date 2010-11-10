#--
#  woot_sync.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-06-24.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

require 'logger'
require 'pathname'
require 'uri'

require 'active_support'
require 'active_support/core_ext/class'
require 'active_support/core_ext/object'

module WootSync
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Connection
  autoload :Image
  autoload :Parser
  autoload :Shops
  autoload :VERSION

  class WootSyncException < StandardError; end
end

require 'woot_sync/railtie'
