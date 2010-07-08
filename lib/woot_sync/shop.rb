#--
#  shop.rb
#  woot_sync-gem
#
#  Created by Jason T. Calhoun on 2010-06-25.
#  Copyright 2010 Taco Stadium. All rights reserved.
#++

require 'pathname'
require 'uri'

module WootSync
  class Shop
    class << self
      include Enumerable

      ##
      # Returns one or more Shop objects mapped to the given arguments. Any
      # invalid arguments are ignored. May be +nil+.
      #--
      # @param [Object] object zero or more objects which map to defined Shop
      #        objects
      #
      # @return [Shop, Array, void] zero or more Shop objects
      #
      # @example
      #   Shop[:woot]         # => #<Shop woot>
      #   Shop[2, 'woot']     # => [#<Shop shirt>, #<Shop woot>]
      #   Shop[:undefined, 1] # => [#<Shop wine>]
      #
      # @see slice
      # @see fetch
      #++
      def [](object, *objects)
        slice(object, objects).send((object.is_a?(Array) or !objects.empty?) ? :to_a : :first)
      end

      ##
      # Iterates the given block using any defined Shop objects.
      #--
      # @yield [Shop] each Shop in order
      #++
      def each(&block)
        Array(WootSync.shops).each { |shop| yield(shop) }
      end

      ##
      # Returns an array of all defined Shop objects in the order specified
      # with any remaining Shop objects appended to the end. Any invalid
      # arguments are ignored. May be empty.
      #--
      # @param [Object] objects zero or more objects which map to defined Shop objects
      #
      # @return [Array] an array containing all defined Shop objects
      #
      # @example
      #   Shop.entries                      # => [#<Shop woot>, #<Shop wine>, #<Shop shirt>, #<Shop sellout>, #<Shop kids>]
      #   Shop.entries(:sellout)            # => [#<Shop sellout>, #<Shop woot>, #<Shop wine>, #<Shop shirt>, #<Shop kids>]
      #   Shop.entries('wine', 4, :invalid) # => [#<Shop wine>, #<Shop kids>, #<Shop woot>, #<Shop shirt>, #<Shop sellout>]
      #
      # @see []
      # @see slice
      # @see fetch
      #++
      def entries(*objects)
        Array((slice(*objects) rescue nil)) | super()
      end
      alias_method :all, :entries
      alias_method :array, :entries
      alias_method :to_a, :entries
      alias_method :to_array, :entries

      ##
      # Returns the first defined Shop which corresponds to the given object.
      #--
      # @param [Shop, String, Symbol, #to_i] object either a Shop object, a
      #        Shop's name as a String or Symbol, or the Shop at the nearest
      #        Integer index in {WootSync#shops}
      #
      # @return [Shop] a Shop object
      #
      # @raise [IndexError] if the given argument cannot be mapped to a defined Shop
      #
      # @example
      #   Shop.fetch('shirt')    # => #<Shop shirt>
      #   Shop.fetch(:shirt)     # => #<Shop shirt>
      #   Shop.fetch(2)          # => #<Shop shirt>
      #   Shop.fetch(Math::E)    # => #<Shop shirt>
      #   Shop.fetch(Shop.shirt) # => #<Shop shirt>
      #   Shop.fetch(:invalid)   # => IndexError: 'invalid' is not a valid Shop
      #
      # @see []
      # @see slice
      #++
      def fetch(object)
        case object
          when self           then object
          when Numeric        then entries.slice(object.to_int)
          when String, Symbol then find { |s| s.name == object.to_s.downcase }
        end or raise(IndexError, "'#{object}' is not a valid #{self.name}")
      end

      ##
      # Returns a hash with symbolized Shop names as keys and Shop objects as
      # values.
      #--
      # @return [Hash] a hash containing each Shop object
      #++
      def hash
        inject((Object.const_get(:HashWithIndifferentAccess) rescue Hash).new) do |h,s|
          h.store(s.to_s, s); h
        end
      end
      alias_method :to_h, :hash
      alias_method :to_hash, :hash

      ##
      # Returns the numeric index of a defined Shop object.
      #--
      # @param [Object] object any object which maps to a defined Shop
      #
      # @return [Fixnum] the numerical index
      #
      # @see fetch
      #++
      def index(object)
        compare = fetch(object)
        entries.index { |s| s.object_id == compare.object_id }
      rescue
        return nil
      end

      ##
      # Returns an array populated with each Shop as a symbol.
      #--
      # @return [Array] an array of Symbol objects
      #
      # @see #to_sym
      #++
      def keys
        map { |s| s.to_sym }
      end

      alias_method :last, :max

      ##
      # Returns the number of defined Shop objects. May be zero.
      #--
      # @return [Fixnum] the number of objects
      #++
      def length
        entries.length
      end
      alias_method :size, :length

      ##
      # Returns the name of this class.
      #--
      # @return [String] the class name
      #++
      def name
        super.split('::').last
      end

      ##
      # Returns an array populated with each Shop as a string.
      #--
      # @return [Array] an array of String objects
      #
      # @see #name
      # @see #to_s
      #++
      def names
        map { |s| s.name }
      end

      ##
      # Returns an array of Shop objects mapped to the arguments provided in
      # the order specified. Any invalid objects are ignored. May be empty.
      #--
      # @param [Object] object one or more objects which map to a defined Shop
      #
      # @return [Array] an array of Shop objects
      #
      # @example
      #   Shop.slice(:woot)         # => [#<Shop woot>]
      #   Shop.slice(2, 'woot')     # => [#<Shop shirt>, #<Shop woot>]
      #   Shop.slice(:undefined, 1) # => [#<Shop wine>]
      #
      # @see []
      # @see fetch
      #++
      def slice(object, *objects)
        (Array(object) + objects).flatten.inject([]) { |a,o| a << (fetch(o) rescue nil) }.compact
      end

      private

        ##
        # Returns the first Shop whose name matches the missing method name.
        #--
        # @param [String] method the missing method name as a string
        #
        # @return [Shop] the matching Shop object
        #
        # @raise [NoMethodError] raised if the method name is not a defined Shop name
        #
        # @example
        #   Shop.sellout # => #<Shop sellout>
        #   Shop.invalid # => NoMethodError: undefined method `invalid' for Shop:Class
        #
        # @see fetch
        # @see []
        #++
        def method_missing(method, *args) # :doc:
          fetch(method) rescue super
        end
    end

    include Comparable

    private_class_method :new

    ##
    # Creates a new Shop object from an array of attributes in the format
    # ['shop_name', {'attribute' => 'value'}].
    #--
    # @private
    #
    # @param [Array] array an array where the first value is the name of the
    #        Shop and the second value is a string key hash of attributes
    #
    # @return [Shop] a newly initialized Shop object
    #
    # @example
    #   shop = Shop.new(['woot', {'host' => 'http://www.woot.com'}]) # => #<Shop woot>
    #   shop.name                                                    # => "woot"
    #   shop.host                                                    # => "http://www.woot.com"
    #++
    def initialize(array) # :nodoc:
      @attributes = {'name' => array.shift}.merge(array.shift).freeze
    end

    ##
    # Returns a Shop attribute for the given key.
    #--
    # @param [String, Symbol] key a string or symbol
    #
    # @return [Object] the attributes hash value for the given key
    #
    # @example
    #   Shop.woot[:epoch]    # => Wed Feb 22 06:00:00 UTC 2006
    #   Shop.woot['host']    # => "http://www.woot.com"
    #   Shop.woot['novalue'] # => nil
    #++
    def [](key)
      (@attributes || {})[key.to_s]
    end

    ##
    # Returns -1, 0, or 1 if the index value of the Shop mapped to the given
    # object is greater than, equal to, or less than that of this Shop
    # instance.
    #--
    # @param [Object] object any object which maps to a defined Shop
    #
    # @return [Fixnum] -1, 0, or 1
    #
    # @example
    #   Shop.wine <=> Shop.woot   # => 1
    #   Shop.sellout <=> :sellout # => 0
    #   Shop.woot <=> 2           # => -1
    #
    # @see fetch
    # @see index
    # @see #index
    #++
    def <=>(object)
      self.index <=> Shop.fetch(object).index
    rescue
      return nil
    end

    alias_method :eql?, :==
    alias_method :equal?, :==

    ##
    # Returns the host attribute as a string. If +as_array+ is true, returns an
    # array containing the sub, primary, and top-level domains, excluding
    # 'www'.
    #--
    # @param [bool] as_array either true or false
    #
    # @return [String, Array] either a string or an array of domain parts
    #
    # @example
    #   Shop.woot.host       # => "http://www.woot.com"
    #   Shop.woot.host(true) # => ["woot", "com"]
    #   Shop.wine.host(true) # => ["wine", "woot", "com"]
    #++
    def host(as_array = false)
      if as_array
        URI.parse(host.to_s).host.slice(/^(www\.)?(.*)/, 2).split('.')
      else
        self['host']
      end
    end

    ##
    # Returns the numeric index of this Shop instance.
    #--
    # @return [Fixnum] the numerical index
    #
    # @see index
    #++
    def index
      self.class.index(self)
    end
    alias_method :to_i, :index
    alias_method :to_int, :index

    ##
    # Returns the host as a new Pathname object with the given +path+ string
    # appended.
    #--
    # @param [String] path the path to a file or directory available at the
    #        Shop instance's domain
    #
    # @return [Pathname] a full path to a remote resource
    #
    # @example
    #   Shop.woot.join('salerss.aspx') # => #<Pathname:http://www.woot.com/salerss.aspx>
    #
    # @see #host
    #++
    def join(path = '')
      Pathname.new(host).join(path)
    end

    ##
    # Returns +self+.
    #--
    # @return [Shop] this Shop instance
    #++
    def shop
      self
    end

    ##
    # Returns the name attribute as a string. If +titelize+ is true, returns a
    # titlecase string containing the Shop instance's full title.
    #--
    # @param [bool] titelize either true or false
    #
    # @return [String]
    #
    # @example
    #   Shop.woot.to_s       # => "woot"
    #   Shop.woot.to_s(true) # => "Woot"
    #   Shop.wine.to_s(true) # => "Woot Wine"
    #++
    def to_s(titelize = false)
      if titelize
        ['Woot', name.capitalize].uniq.join(' ')
      else
        name
      end
    end
    alias_method :to_str, :to_s

    ##
    # Returns the name attribute as a symbol.
    #--
    # @return [Symbol]
    #++
    def to_sym
      name.to_sym
    end

    private

      ##
      # Returns the attribue value for the missing method name if it exists.
      # If the method name ends in a question mark ('?') and maps to a defined
      # Shop, evaluates whether this Shop instance is equal to that Shop
      # object.
      #--
      # @param [String] method the missing method name as a string
      #
      # @return [Object, bool]
      #
      # @raise [NoMethodError] raised if the method name does not map to an
      #        attribute or a defined Shop
      #
      # @example
      #   Shop.sellout.epoch   # => Wed Feb 22 06:00:00 UTC 2006
      #   Shop.sellout.invalid # => NoMethodError: undefined method `invalid' for #<Shop:0x1015af710>
      #
      #   Shop.sellout.sellout? # => true
      #   Shop.sellout.shirt?   # => false
      #   Shop.sellout.invalid? # => NoMethodError: undefined method `invalid?' for #<Shop:0x1015af710>
      #
      # @see #[]
      #++
      def method_missing(method, *args) # :doc:
        if (shop_name = method.to_s).slice!(-1..-1).eql?('?') && Shop.include?(shop_name)
          self.equal?(shop_name)
        elsif @attributes.keys.include?(method.to_s)
          self[method.to_s]
        else
          super
        end
      end
  end
end
