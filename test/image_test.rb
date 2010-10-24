#--
#  image_test.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-10-24.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

require 'helper'

class ImageTest < Test::Unit::TestCase
  context 'WootSync::Image' do
    setup do
      @suffixes = WootSync::Image.suffixes

      @base_url = {
        'new' => 'http://example.com/Image000%s.jpg',
        'old' => 'http://example.com/Image-%s.jpg'
      }

      %w(new old).each do |style|
        instance_variable_set(:"@#{style}_url", @suffixes.inject({}) { |h,s| h.store(s, @base_url[style] % s); h })
      end
    end

    context '#valid?' do
      should 'validate strings in the old image url style' do
        key = @suffixes[0]
        assert_equal key, WootSync::Image.valid?(@old_url[key])
      end

      should 'validate strings in the new image url style' do
        key = @suffixes[0]
        assert_equal key, WootSync::Image.valid?(@new_url[key])
      end

      should 'accept a number of objects that can be cast as a string' do
        key = @suffixes[0]
        assert_equal key, WootSync::Image.valid?(URI.parse(@new_url[key]))
        assert_equal key, WootSync::Image.valid?(Pathname.new(@new_url[key]))
        assert_equal key, WootSync::Image.valid?(WootSync::Image.new(@new_url[key]))
      end

      should 'return false if the given string is not a valid url' do
        assert_equal false, WootSync::Image.valid?('/Invalid/Image-Standard.jpg')
      end

      should 'return false if the suffix of the given string is not valid' do
        assert_equal false, WootSync::Image.valid?(@base_url['new'] % 'invalid')
      end
    end

    context '#parse' do
      should 'receive a single string' do
        key = @suffixes[0]
        assert_equal({key => WootSync::Image.new(@new_url[key])}, WootSync::Image.parse(@new_url[key]))
      end

      should 'receive an array of strings' do
        key1, key2, = @suffixes
        assert_equal({key1 => WootSync::Image.new(@new_url[key1]), key2 => WootSync::Image.new(@new_url[key2])},
          WootSync::Image.parse(@new_url.values_at(key1, key2)))
      end

      should 'receive a hash with strings as values' do
        assert_equal(@new_url.inject({}) { |h,(k,v)| h.store(k, WootSync::Image.new(v)); h }, WootSync::Image.parse(@new_url))
      end

      should 'ignore urls that do not contain a valid suffix' do
        key     = @suffixes[0]
        invalid = @base_url['new'] % 'Invalid'

        assert_equal({}, WootSync::Image.parse(invalid))
        assert_equal({key => WootSync::Image.new(@new_url[key])}, WootSync::Image.parse([@new_url[key], invalid]))
      end

      should 'ignore strings that are not valid urls' do
        key     = @suffixes[0]
        invalid = "/bad/url/Image-#{key}.jpg"

        assert_equal({}, WootSync::Image.parse(invalid))
        assert_equal({key => WootSync::Image.new(@new_url[key])}, WootSync::Image.parse([@new_url[key], invalid]))
      end
    end
  end
end
