require 'logger'

module WootSync
  class Base
    include ActiveSupport::Configurable
    config_accessor :logger
  end

  Base.class_eval do
    include Connection
    include Images
    include Parser
    include Shops
  end
end
