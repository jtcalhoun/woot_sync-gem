require 'helper'

class ShopsTest < Test::Unit::TestCase

  SETTINGS      = YAML.load_file(File.expand_path('../../config/settings.yml', __FILE__))['shops']
  DEFAULT_NAMES = SETTINGS.map { |v| v.keys[0] }
  DEFAULT_SHOPS = DEFAULT_NAMES.inject([]) { |a,s| a << WootSync::Shop[s] }

  context 'WootSync configuration' do
    teardown { WootSync::Base.config.shops = SETTINGS }

    should 'load default Shop information from config/settings.yml' do
      default_keys = DEFAULT_NAMES.sort
      loaded_keys  = WootSync::Base.config.shops.map { |s| s.name }.sort

      assert_equal default_keys, loaded_keys
    end

    should 'allow the default Shop values to be overridden' do
      default_shop = WootSync::Base.config.shops.first
      assert_not_nil default_shop

      # Override the default Shop values.
      WootSync::Base.config.shops = [{'test' => {'host' => 'http://test.woot.com'}}]

      assert_not_equal default_shop, WootSync::Base.config.shops.first
    end

    should 'assign the @shops instance variable as an array of Shop objects' do
      types = WootSync::Base.config.shops.map { |s| "#{s.class}" }.uniq
      assert_equal 1, types.length
      assert_equal 'WootSync::Shop', types[0]
    end

    should 'prevent new Shop objects from being initialized directly' do
      assert_raises(NoMethodError) { WootSync::Shop.new(['test', {'host' => 'http://test.woot.com'}]) }
    end
  end

  context 'Shop#fetch' do
    should 'accept a Shop and return the same object as the argument provided' do
      assert DEFAULT_SHOPS[0] === WootSync::Shop.fetch(DEFAULT_SHOPS[0])
    end

    should 'accept a String and return the first Shop whose name matches' do
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.fetch(DEFAULT_NAMES[0].to_s)
    end

    should 'accept a Symbol and return the first Shop whose name matches as a string' do
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.fetch(DEFAULT_NAMES[0].to_sym)
    end

    should 'accept a Numeric value and return the value in the Shop.entries array at that Integer index' do
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.fetch(0)
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.fetch(0.010010102)
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.fetch(0 - DEFAULT_NAMES.length)
    end

    should 'raise an IndexError exception if the requested Shop is not defined' do
      assert_raises(IndexError) { WootSync::Shop.fetch('notfound') }
      assert_raises(IndexError) { WootSync::Shop.fetch(:notfound) }
      assert_raises(IndexError) { WootSync::Shop.fetch(DEFAULT_NAMES.length) }
    end

    should 'raise an IndexError exception if an unexpected argument value is provided' do
      assert_raises(IndexError) { WootSync::Shop.fetch(true) }
      assert_raises(IndexError) { WootSync::Shop.fetch(nil) }
      assert_raises(IndexError) { WootSync::Shop.fetch(Object.new) }
    end
  end

  context 'Shop#[]' do
    should 'return a single Shop object if only one argument is provided' do
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop[DEFAULT_NAMES[0]]
    end

    should 'return an array of Shop objects in the order requested if multiple arguments are given' do
      assert_equal DEFAULT_SHOPS[-3..-1], WootSync::Shop[DEFAULT_NAMES[-3], DEFAULT_NAMES[-2], DEFAULT_NAMES[-1]]
      assert_equal DEFAULT_SHOPS[-3..-1], WootSync::Shop[DEFAULT_NAMES[-3..-2], DEFAULT_NAMES[-1]]
    end

    should 'ignore invalid Shops and return an array even with zero or one keys' do
      assert_equal [], WootSync::Shop[:invalid, DEFAULT_NAMES.length, 'notfound']
      assert_equal [DEFAULT_SHOPS[0]], WootSync::Shop[:invalid, DEFAULT_NAMES[0], DEFAULT_NAMES.length, 'notfound']
    end

    should 'return nil if the requested Shop is not defined' do
      assert_nil WootSync::Shop['notfound']
      assert_nil WootSync::Shop[:notfound]
      assert_nil WootSync::Shop[DEFAULT_NAMES.length]
    end
  end

  context 'Shop#slice' do
    should 'return an array of zero or more Shop objects in the order of the arguments given' do
      assert_equal DEFAULT_SHOPS[-3..-1], WootSync::Shop.slice(DEFAULT_NAMES[-3], DEFAULT_NAMES[-2], DEFAULT_NAMES[-1])
      assert_equal [DEFAULT_SHOPS[0]], WootSync::Shop.slice(DEFAULT_NAMES[0])
    end

    should 'ignore invalid Shops' do
      assert_equal [], WootSync::Shop.slice([:invalid, DEFAULT_NAMES.length, 'notfound'])
      assert_equal [DEFAULT_SHOPS[0]], WootSync::Shop.slice(:invalid, DEFAULT_NAMES[0], DEFAULT_NAMES.length, 'notfound')
    end
  end

  context 'Shop#entries' do
    should 'return an array of all Shop objects in the order they were defined if no arguments are given' do
      assert_equal DEFAULT_SHOPS, WootSync::Shop.entries
    end

    should 'return an array in the order of the arguments given, appending any remainders to the end' do
      assert_equal [DEFAULT_SHOPS[-1], DEFAULT_SHOPS.slice(0..-2)].flatten, WootSync::Shop.entries(DEFAULT_NAMES[-1])
    end

    should 'ignore any invalid Shops and return the array' do
      assert_equal DEFAULT_SHOPS, WootSync::Shop.entries(:invalid, 'notfound', DEFAULT_NAMES.length)
    end
  end

  context 'Shop#hash' do
    should 'create a hash from each defined Shop' do
      assert_equal DEFAULT_SHOPS.inject({}) { |h,s| h.store(s.to_sym, s); h }, WootSync::Shop.hash
    end
  end

  context 'Shop#index' do
    should 'return the numeric index of the Shop in a Shop.entries array' do
      assert_equal DEFAULT_NAMES.index((n = DEFAULT_NAMES[-1])), WootSync::Shop.index(n)
      assert_equal DEFAULT_NAMES.map { |x| x.to_sym }.index(n.to_sym), WootSync::Shop.index(n.to_sym)
      assert_equal 0, WootSync::Shop.index(DEFAULT_SHOPS[0])
    end

    should 'return nil if the argument given does not exist in the array' do
      assert_nil WootSync::Shop.index(DEFAULT_NAMES.length)
    end
  end

  context 'Shop#keys' do
    should 'return an array of symbols for each Shop name' do
      assert_equal DEFAULT_NAMES.map { |n| n.to_sym }, WootSync::Shop.keys
    end
  end

  context 'Shop#length' do
    should 'return the number of Shop objects in the Shop.entries array' do
      assert_equal DEFAULT_NAMES.length, WootSync::Shop.length
    end
  end

  context 'Shop#names' do
    should 'return an array of strings for each Shop name' do
      assert_equal DEFAULT_NAMES, WootSync::Shop.names
    end
  end

  context 'Shop#method_missing' do
    should 'return a Shop object if the given method name corresponds to a defined Shop name or raise a NoMethodError' do
      assert_equal DEFAULT_SHOPS[0], WootSync::Shop.send(DEFAULT_NAMES[0])
      assert_raises(NoMethodError) { WootSync::Shop.notfound }
    end
  end

  context 'Shop.method_missing' do
    should 'evaluate whether the Shop object is equal to the method name if that name ends in a question mark' do
      assert DEFAULT_SHOPS[0].send("#{DEFAULT_NAMES[0]}?")
      assert !DEFAULT_SHOPS[-1].send("#{DEFAULT_NAMES[0]}?") if DEFAULT_NAMES.length > 1
    end

    should 'return the corresponding attribute value for the given key if one exists' do
      assert_equal DEFAULT_SHOPS[0].instance_variable_get(:@attributes)['epoch'], WootSync::Shop[DEFAULT_NAMES[0]][:epoch]
      assert_equal DEFAULT_SHOPS[0].instance_variable_get(:@attributes)['epoch'], WootSync::Shop[DEFAULT_NAMES[0]]['epoch']
      assert_equal DEFAULT_SHOPS[0].instance_variable_get(:@attributes)['epoch'], WootSync::Shop[DEFAULT_NAMES[0]].send('epoch')

      assert_nil WootSync::Shop[DEFAULT_NAMES[0]]['novalue']
      assert_nil WootSync::Shop[DEFAULT_NAMES[0]][0]
      assert_raises(NoMethodError) { WootSync::Shop[DEFAULT_NAMES[0]].send('novalue') }
    end
  end

  if DEFAULT_NAMES.length > 1
    context 'Shop.<=>' do
      should 'compare to other objects based on values obtained from Shop.index' do
        assert_equal -1, (WootSync::Shop[DEFAULT_NAMES[0]] <=> WootSync::Shop[DEFAULT_NAMES[1]])
        assert_equal 0, (WootSync::Shop[DEFAULT_NAMES[0]] <=> WootSync::Shop[DEFAULT_NAMES[0]])
        assert_equal 1, (WootSync::Shop[DEFAULT_NAMES[1]] <=> WootSync::Shop[DEFAULT_NAMES[0]])
      end

      should 'accept a comparison on any object that will map to a defined Shop' do
        assert_equal -1, (WootSync::Shop[DEFAULT_NAMES[0]] <=> DEFAULT_NAMES[1])
        assert_equal 0, (WootSync::Shop[DEFAULT_NAMES[0]] <=> DEFAULT_NAMES[0].to_sym)
        assert_equal 1, (WootSync::Shop[DEFAULT_NAMES[1]] <=> 0)
        assert_equal 0, (WootSync::Shop[DEFAULT_NAMES[0]] <=> DEFAULT_SHOPS[0])
      end

      should 'enable equality comparisons based on the same criteria' do
        assert WootSync::Shop[DEFAULT_NAMES[0]] == 0
        assert WootSync::Shop[DEFAULT_NAMES[0]].eql?(DEFAULT_NAMES[0])
        assert WootSync::Shop[DEFAULT_NAMES[0]].equal?(DEFAULT_SHOPS[0])
      end
    end
  end

  context 'Shop.host' do
    should 'return an array of domain parts if a true argument is given' do
      host = SETTINGS[-1][DEFAULT_NAMES[-1]]['host'].split('/', 3).last.split('.')
      host.shift if host[0] == 'www'

      assert_equal host, WootSync::Shop[DEFAULT_NAMES[-1]].host(true)
    end
  end
end
