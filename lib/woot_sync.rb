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
  autoload :Images
  autoload :Parser
  autoload :Shops
  autoload :VERSION

  class WootSyncException < StandardError; end
end

require 'woot_sync/railtie'
