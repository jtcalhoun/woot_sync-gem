require 'active_support/configurable'

module WootSync
  class Base
    include ActiveSupport::Configurable
    config_accessor :logger
  end

  Base.class_eval do
    include Connection
    include Shops
  end
end
