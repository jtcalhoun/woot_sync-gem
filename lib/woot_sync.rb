$:.unshift File.dirname(File.expand_path(__FILE__))

require 'active_support'

module WootSync
  extend ActiveSupport::Autoload

  autoload :Images
  autoload :Client
  autoload :Parser
  autoload :Railtie
  autoload :Shop
  autoload :VERSION

  class WootSyncException < StandardError; end
  include ActiveSupport::Configurable

  # Pretend like this is a Class when Rails checks to see if it's superclass
  # has any inheritable configuration options.
  def self.superclass; Object; end

  config_accessor :logger
end

WootSync::Railtie.load_settings!
WS = WootSync
