module WootSync
  class Image < Pathname
    class << self

      ##
      # Returns the native file extension for Woot images.
      #--
      # @return [String] a file extension preceeded by a period
      #
      # @example
      #   WootSync::Image.extname # => '.jpg'
      #++
      def extname
        WootSync::Base.config.images.try(:[], 'extname') || ''
      end

      ##
      # Returns a Hash of Image instances created from one or more absolute
      # urls to Woot.com image files.
      #--
      # @param [Array, Hash, String] array_hash_or_string one or more
      #        absolute woot image urls
      #
      # @return [Hash] a hash containing WootSync:Image objects in the
      #         format {:suffix => #<Image>}
      #
      # @example
      #   Image.parse('http://example.com/Pig0e7Detail.jpg')          # => {"detail" => #<Image:http://...>}
      #   Image.parse(['http://example.com/OldSyntax-thumbnail.png']) # => {"thumbnail" => #<Image:http://...>}
      #++
      def parse(array_hash_or_string)
        paths = case array_hash_or_string
          when Array  then array_hash_or_string
          when Hash   then array_hash_or_string.values
          when Pathname, String, URI then Array(array_hash_or_string.to_s.split($/))
          else return {}
        end

        paths = paths.select { |v| valid?(v) }.compact.uniq.map { |v| new(v) }
        paths.inject({}) { |h,v| h.store(v.suffix, v); h }
      end

      ##
      # Returns an array of valid Woot image suffixes.
      #--
      # @return [Array] an array of suffixes as strings
      #
      # @example
      #   WootSync::Image.suffixes # => ['detail', 'standard', 'thumbnail']
      #++
      def suffixes
        Array(WootSync::Base.config.images.try(:[], 'suffixes').try(:keys))
      end

      ##
      # Returns a suffix if the string given is a valid Woot.com image url.
      #--
      # @param [Pathname, String, URI] string an absolute url string
      #
      # @return [String] the suffix for the given string
      #
      # @raise [ArgumentError] raised if the argument given is not a String
      #
      # @example
      #   WootSync::Image.valid?('http://example.com/Image000Detail.jpg') # => "detail"
      #   WootSync::Image.valid?('http://example.com/Image-Standard.jpg') # => "standard"
      #   WootSync::Image.valid?('http://example.com/Image-Invalid.jpg')  # => false
      #   WootSync::Image.valid?('/relative/path/Image000Thumbnail.jpg')  # => false
      #++
      def valid?(string)
        suffix = nil
        string = case string
          when Pathname, String, URI then string.to_s
          else raise(ArgumentError, 'argument must be a string')
        end

        if string =~ URI.regexp('http')
          suf = '(%s)' % suffixes.join('|')
          ext = '\.(.+)$'

          suffix, = string.downcase.match((string =~ /-#{suf}#{ext}/i) ?
            /(.*)-(.*)#{ext}/i : /^(.*)...#{suf}#{ext}/i).to_a.slice(-2,1)
        end

        return (suffix || false)
      end
    end

    attr_reader :suffix

    ##
    # Creates a new Image from an absolute url string.
    #--
    # @param [String] string an absolute url
    #
    # @return [Image] a newly initialized Image object
    #
    # @raise [ArgumentError] raised if the string provided is not an
    #        absolute url
    #
    # @example
    #   image = Image.new('http://example.com/AWoot123Standard.jpg') # => #<Image:http://...>
    #   image.suffix                                                 # => "standard"
    #
    #   image2 = Image.new('/relative/path/AWoot123Standard.jpg')    # => ArgumentError: argument must be an absolute url with a valid suffix
    #++
    def initialize(string)
      raise ArgumentError, 'argument must be an absolute url with a valid suffix' \
        unless (@suffix = self.class.valid?(string))

      super
    end

    ##
    # Returns the last component of the path.
    #--
    # @return [String] the last component of the path
    #++
    def basename
      File.basename(@path)
    end

    ##
    # Returns true if the path extname is the expected file format.
    #--
    # @return [bool] either true or false
    #
    # @example
    #   Image.new('http://example.com/Image-Standard.jpg').valid_extname? # => true
    #   Image.new('http://example.com/Image-Standard.mp4').valid_extname? # => false
    #++
    def valid_extname?
      extname == self.class.extname
    end
  end
end
