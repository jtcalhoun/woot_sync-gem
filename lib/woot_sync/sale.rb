require 'htmlentities'

module WootSync
  class Sale
    module ParserMixin
      extend ActiveSupport::Concern

      SALE_STATUSES = Array(WootSync.config.parser['statuses'])

      DEFAULT_STATUS = SALE_STATUSES.first

      MAXIMUM_TOKEN_LENGTH = 50

      # Use the old script instead of /SaleStats.aspx?wootsaleid=%s
      # because the former includes the product thumbnail image.
      SCRIPT_PATH = 'scripts/dynamic.aspx?control=salesummary&saleid=%s'

      UNIQUE_ATTRIBUTES = %w(forum_url number blog_url)

      module ClassMethods

        def parse_summary(shop, string)
          parts = string.to_s.strip.split(' : ')
          parts.map! { |r| r.strip if r.kind_of?(String) }

          keys = begin
            if parts[0] =~ /.*%$/
              {'progress' => 0, 'price' => 1, 'name' => 2, 'status' => 3}
            else
              {'price' => 0, 'name' => 1, 'status' => 2}
            end
          end

          parts[keys['price']]    = parts[keys['price']].to_s.match(/^\$?(.*)$/)[1].to_f
          parts[keys["progress"]] = parts[keys['progress']].to_s.match(/(\d*)%?/)[1].to_f / 100 if keys["progress"]

          parts[keys['status']] ||= DEFAULT_STATUS

          attributes = {
            "woot"    => {"name" => parts[keys.delete("name")]},
            "shop"    => WS::Shop[shop].name,
            "wootoff" => keys["progress"].present?
          }

          attributes.merge!(keys.inject({}) { |h,(k,v)| h.store(k, parts[v]); h })

          attributes
        end

        ##
        # Generates a human-readable identifier for a given string.
        #
        # @param [String] string the string to be converted to a token
        # @return [String] a tokenized string containing only standard letters,
        #         numbers, and underscores
        # @example
        #   WootSync::Parser.tokenize("Beyond Smart Mill & Brew Coffee Maker")    # => "beyond_smart_mill_brew_coffee_maker"
        #   WootSync::Parser.tokenize("RC Cyclone Revolution Stunt Car - 2 Pack") # => "rc_cyclone_revolution_stunt_car_2_pack"
        #
        def tokenize(string)
          # Decode any HTML Entities before normalizing below.
          coder  = HTMLEntities.new
          string = coder.decode(string)

          # 1. Normalize string to remove accented characters.
          # 2. Convert to lowercase.
          # 3. Remove any other special characters.
          # 4. Convert consecutive spaces and underscores into a single underscore.
          # 5. Remove leading and trailing underscores.
          # .............[1].....................[2]......[3].................[4].................[5]
          token = string.mb_chars.normalize(:kd).downcase.gsub(/[^\w ]/u, '').gsub(/[ _]+/u, '_').slice(/^_*(.*?)_*$/u, 1).to_s

          # Limit the token to MAXIMUM_TOKEN_LENGTH characters.
          if token.length > MAXIMUM_TOKEN_LENGTH
            token = token[0..(MAXIMUM_TOKEN_LENGTH - 1)]
            token = token.slice(/(.+)(?=_)/, 1) if token.include?('_')
          end

          # Remove trailing numerical digits to avoid confusion when handling
          # duplicate tokens, and also trailing prepositions and conjunctions.
          trailing = %w([0-9]+ and by for from in into of on onto or per the till to until up via with without)
          token = token.slice(/^(.+?)(_(#{trailing.join('|')}))*$/, 1)

          return token
        end
      end

      module InstanceMethods

        SALE_STATUSES.each do |status|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{status.delete(' ').underscore}?
              attributes['status'] == '#{status}'
            end
          RUBY_EVAL
        end

        def <=>(other)
          return nil unless other.acts_like?(:sale)

          was = self.normalize
          now = other.normalize

          common_keys = was.keys & now.keys

          changes = common_keys.select do |field|
            if was[field] != now[field]
              WootSync.logger.debug("#{field} has changed (was: #{was[field]}, now: #{now[field]})")
              true
            else false
            end
          end

          if changes.empty? then 0
          elsif (changes & UNIQUE_ATTRIBUTES).any? then 1
          elsif (changes.include?("progress") && changes.size.eql?(1)) then 2
          else -1
          end
        end

        def acts_like_sale?
          true
        end

        ##
        # Returns +true+ if the Sale status is Sold Out or Ended.
        #
        # @return [bool] either true or false
        #
        def finished?
          sold_out? or ended?
        end

        def normalize
          sale = attributes
          woot = self.woot.attributes rescue sale['woot']

          hash = sale.slice(*UNIQUE_ATTRIBUTES).merge({
            'name'     => (self.class.tokenize(woot.try(:[], 'name')).upcase rescue nil),
            'status'   => sale['status'].to_s.upcase,
            'price'    => sale['price'].to_s.scan(/^\$?(.*)/).flatten.first.to_f
          })

          hash["progress"] = on_sale? ? sale["progress"].to_f : 0.0 if wootoff?

          return hash
        end

        def wootoff?
          (attributes["wootoff_id"] || attributes["wootoff"]).present?
        end
      end
    end

    include ParserMixin

    attr_reader :attributes

    def initialize(hash = {})
      raise 'argument must be a Hash of attributes' unless hash.is_a?(Hash)

      hash['shop'] = WootSync::Shop.fetch(hash['shop'])
      @attributes = hash
    end

    def shop
      @attributes['shop']
    end
  end
end
