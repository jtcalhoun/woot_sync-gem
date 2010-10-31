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
require 'active_support/core_ext/object'

module WootSync
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :VERSION
    autoload :Base
    autoload :Connection
    autoload :Image
    autoload :Shops
  end
end

WootSync::Base.configure do |b|

  b.logger = Logger.new(STDOUT)

  begin
    require 'erb'

    load_path = File.expand_path('../../config/settings.yml', __FILE__)

    (YAML::load(ERB.new(IO.read(load_path)).result) || {}).each do |k,v|
      b.send("#{k}=", v)
    end
  rescue Errno::ENOENT
    warn 'WARNING: could not load WootSync settings file'
  end
end
