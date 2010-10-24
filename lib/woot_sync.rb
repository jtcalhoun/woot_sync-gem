#--
#  woot_sync.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-06-24.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

module WootSync
  autoload :Image, 'woot_sync/image'
  autoload :Shop,  'woot_sync/shop'

  class << self

    ##
    # Returns the value of attribute shops.
    #--
    # @return [Array] an array of Shop objects
    #++
    attr_reader :shops

    ##
    # Yields +self+ for easier block configuration.
    #--
    # @return [void]
    #
    # @example
    #   WootSync.configure do |config|
    #     config.shops = [{'woot' => {'host' => 'http://www.woot.com'}}]
    #   end
    #++
    def configure(&block)
      yield self
      return
    end

    ##
    # Stores attributes for Woot image files.
    #--
    # @param [Hash] hash a string keyed hash of attributes
    #
    # @return [Hash] a hash of valid attributes
    #
    # @example
    #   WootSync.images = {'extname' => '.jpg', 'sizes' => ['detail', 'thumbnail', 'standard']}
    #++
    def images=(hash)
      WootSync::Image.configure(hash)
    end

    ##
    # Stores an array of Shop names and attributes as an array of Shop
    # objects.
    #--
    # @param [Array] array an array populated with string keyed hashes in
    #        the form of [{'shop_name' => {'key' => 'value'}}]
    #
    # @return [Array] the array of Shop objects
    #
    # @example
    #   WootSync.shops = [{'woot' => {'host' => 'http://www.woot.com'}}, {'wine' => {'host' => 'http://wine.woot.com'}}]
    #++
    def shops=(array)
      @shops = Array(array).flatten.inject([]) { |a,h| a << WootSync::Shop.send(:new, h.to_a.flatten).freeze }
    end
  end
end

WootSync.configure do |config|
  begin
    YAML.load_file(File.expand_path('../../config/settings.yml', __FILE__)).each do |k,v|
      config.send "#{k}=", v
    end
  rescue Errno::ENOENT
    warn 'WARNING: could not load WootSync settings file'
  end
end
