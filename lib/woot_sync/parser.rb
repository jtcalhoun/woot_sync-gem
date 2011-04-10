$KCODE = 'UTF8'

require 'active_support/time'
require 'htmlentities'
require 'nokogiri'

Time.zone ||= ActiveSupport::TimeZone.new(WootSync.config.parser['timezone'])

module WootSync
  class Parser
    module ParserMixin
      extend ActiveSupport::Concern

      DEFAULT_STATUS = Array(WootSync.config.parser['statuses']).first
      UNIQUE_FIELDS  = %w(number forum_url blog_url)

      module ClassMethods
        def from_homepage(shop, string)
          # raise ParseError, "Unable to parse Sale info from SaleRSS." if response.body.empty?

          body = Nokogiri::HTML(string.to_s)

          attributes = {
            'woot' => {
              'name'     => body.at('div.productDescription h2').inner_html,
              'products' => body.at('div.productDescription dl').search('dt').inject([]) { |a,e|
                if e.inner_html.strip =~ /^product/i
                  product = e.next.next.inner_html.match(/(\d+)[ \r\t\n]+([^<\n\r\t]+)/)
                  a << {'quantity' => product[1].to_i, 'name' => product[2]}
                else a
                end
              },
              'images'   => {
                'detail'    => body.at('img.photo').parent[:href],
                'standard'  => body.at('img.photo')[:src],
                # 'thumbnail' => # meta tag
              }
            },

            'condition'   => body.at('div.productDescription dd').inner_html.to_s.strip,
            'description' => body.at('div.writeUp').inner_html.to_s.strip,
            'forum_url'   => ((forum_url = body.at('li.discuss a')) ? forum_url[:href] : nil),
            'launch'      => !body.at("div[@id$=LaunchPanel]").nil?,
            'number'      => ((m = string.to_s.match(/wootsaleid=(\d+)/i)).nil? ? nil : m[1].to_i),
            'price'       => body.at('div.productDescription span.amount').inner_html.to_s.match(/^\$?(.*)$/)[1],
            'shipping'    => body.at('ul#shippingOptions li').inner_html,
            'shop'        => shop.name,
            'title'       => body.at('div.story h2').inner_html.to_s.strip,
            # 'wootoff'     => !body.at('.wootOff').nil?
          }

          attributes['status'], attributes['purchase_url'] = begin
            case (link = body.at('a[@id$=HyperLinkWantOne]'))[:class].to_s
            when /soldOut/i
              'Sold Out'
            else
              attributes['urgent'] = link[:class].to_s.include?('urgent')
              [DEFAULT_STATUS, (link[:href].empty? ? nil : link[:href].to_s)]
            end
          end

          if progress = body.at('div[@id$=ProgressBar]')
            attributes['progress'] = progress.at('div.wootOffProgressBarValue')[:style].scan(/width: ?(\d+)%/i).first.first.to_i
          end

          new(attributes)
        end

        def from_salerss(shop, string)
          body = Nokogiri::XML(string.to_s).remove_namespaces!
          item = body.at('item')

          # raise ParseError, "Unable to parse Sale info from SaleRSS." if item.nil?

          attributes = {
            'woot' => {
              'name'     => item.at('title').inner_html,
              'products' => item.search('product').inject([]) { |a,(v,k)| a << "#{v['quantity']} #{v.inner_html}" },
              'images'   => {
                'detail'        => item.at('detailimage').inner_html,
                'standard'      => item.at('standardimage').inner_html,
                # 'shoppingyahoo' => item.at('substandardimage').inner_html,
                'thumbnail'     => item.at('thumbnailimage').inner_html
              }
            },

            'blog_url'     => ((b = item.at('blogurl')) && b.inner_html),
            'condition'    => item.at('condition').inner_html,
            'description'  => item.at('description').inner_html.to_s.strip,
            'forum_url'    => item.at('discussionurl').inner_html,
            'number'       => ((g = item.at('guid').inner_html.scan(/WootSaleId=(\d+)/i).first) ? g.first : nil),
            'price'        => item.at('price').inner_html.to_s.match(/^\$?(.*)$/)[1],
            'progress'     => ((1 - item.at('soldoutpercentage').inner_html.to_f) * 100).to_i,
            'purchase_url' => item.at('purchaseurl').inner_html,
            'shipping'     => item.at('shipping').inner_html,
            'shop'         => shop.name,
            'status'       => ((item.at('soldout').inner_html.downcase.eql?('true') && 'Sold Out') || DEFAULT_STATUS),
            'title'        => item.at('subtitle').inner_html,
            'wootcast_url' => ((enclosure = item.at('enclosure')) ? enclosure[:url] : nil),
            'wootoff'      => (item.at('wootoff').inner_html.to_s.downcase == 'true')
          }

          attributes['start'] = Time.parse((attributes['wootoff'] ? body.at('rss/channel/pubDate') : item.at('pubDate')).inner_html.chomp('GMT'))

          new(attributes)
        end

        def from_summary(shop, string)
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
          parts[keys['progress']] = parts[keys['progress']].to_s.match(/(\d*)%?/)[1].to_i if keys['progress']

          parts[keys['status']] ||= DEFAULT_STATUS

          attributes = {'woot' => {'name' => parts[keys.delete('name')]}, 'shop' => shop.name}
          attributes.merge!(keys.inject({}) { |h,(k,v)| h.store(k, parts[v]); h })

          new(attributes)
        end
      end

      module InstanceMethods
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
          elsif (changes & UNIQUE_FIELDS).any? then 1
          else -1
          end
        end

        def acts_like_sale?
          true
        end

        ##
        # Returns +true+ if the status attribute does not equal the default
        # status.
        #
        # @return [bool] either +true+ or +false+
        #
        def finished?
          attributes['status'] != DEFAULT_STATUS
        end

        def normalize
          sale = attributes
          woot = self.woot.attributes rescue sale['woot']

          hash = sale.slice(*UNIQUE_FIELDS).merge({
            'name'     => WootSync::Parser.tokenize(woot.try(:[], 'name')).upcase,
            'status'   => sale['status'].to_s.upcase,
            'price'    => sale['price'].to_f
          })

          hash['progress'] = sale['progress'].to_f if sale['wootoff'].eql?(true)

          return hash
        end

        def update_stats!(string)
          body = Nokogiri::HTML(string.strip.gsub('\"', '"').match(/^document\.write\(["'] *(.*) *["']\);/)[1])

          # Remove the improperly nested <div> in the Shirt sale attributes.
          if invalid_div = body.at('.saleStats-thread')
            body = Nokogiri::HTML(body.to_s.gsub("</dl>#{invalid_div.to_s}", ''))
          end

          sale = self.attributes
          sale['woot'] ||= {}

          if (img = body.at('.thumbnail'))
            sale['woot']['images'] ||= {}
            sale['woot']['images'].reverse_merge!({
              'thumbnail' => img[:src],
              'detail'    => img.parent[:href]
            })
          end

          if (a = body.at('a#HyperLinkTitle'))
            sale['wootcast_title'] = a.inner_html
            sale['wootcast_url']   = a[:href]
          end

          if (dl = body.at('dl[@class=itemSummary]'))
            sale['woot']['name'] = ((dt = dl.at('dt')) ? (dt.at('a') || dt).inner_html : nil)
            sale['blog_url'] = ((a2 = dl.at('dt a')) ? a2[:href] : nil)

            first_speed = nil

            dl.search('dd').each do |dd|
              next unless dd.inner_html =~ /[\r\n\t ]*([^>]+): *(.*)/i

              case (fields = dd.inner_html.split(':', 2).map{ |f| f.strip }).first.downcase

              when /blame|last wooter/
                sale['blame']  = fields.last
                sale['status'] = 'Sold Out' if fields.first =~ /sellout/i
                # sale['status'] = 'Ended' if fields.first =~ /last wooter/i

              when /pace/
                order_pace  = fields.last.match(/(([0-9\.]+)h)? *(([0-9\.]+)m)? *(([0-9\.]+)s)?/i)
                sale['pace'] = (order_pace[2].to_f * 3600) + (order_pace[4].to_f * 60) + (order_pace[6].to_f)

              when /(quantity|woots sold|total woots)/
                sale['quantity'] = fields.last.to_i
                sale['status']   = 'Sold Out' if fields.first =~ /total woots/i

              when /(sellout time|last purchase time)/
                sale['end'] = fields.last

                if fields.first =~ /sellout time/i
                  sale['status'] = 'Sold Out'
                  sale_finished  = true
                end

              when /speed/
                first_speed = fields.last.match(/(\d+)m +?([-\d\.]+)s/)

              when /sucker/
                sale['sucker'] = fields.last

              when /wage/
                sale['wage'] = fields.last.gsub(/[^\d]/,'').to_i
              end
            end

            sale['speed'] = (first_speed.nil? ? nil : ((first_speed[1].to_f * 60) + first_speed[2].to_f))

            hour_count = 0
            body.css('table.hours td').each do |td|
              hour_label = 'hour_' + (hour_count > 9 ? hour_count.to_s : "0#{hour_count}")
              sale.store(hour_label, ((td.at('div')[:title].to_i || 0) / 100.0))
              hour_count += 1
            end

            day_count = [1, 2, 3, 4, 5, 6, 0]
            body.css('table.days td').each do |td|
              day_label = "day_#{Date::ABBR_DAYNAMES[day_count.shift].downcase}"
              sale.store(day_label, ((td.at('div')[:title].to_i || 0) / 100.0))
            end
          end

          (labels = %w(one two three)).each do |label|
            begin
              bought_label = "bought_#{label}"
              sale.store(bought_label, (body.to_s.match(/(\d+)% +bought +#{labels.index(label) + 1}/i)[1].to_i / 100.0))
            rescue NoMethodError
              # Do nothing.
            end
          end

          # If sale[:end] is greater than 00:01:30 and less than 23:50:00,
          # assume that the Sale has Sold Out. Otherwise assume that it has
          # Ended. This may prove inaccurate for some Wootoff Sales, but
          # these should be resolved server-side.
          if !(sale_finished ||= false) and !sale['end'].nil?
            sale['status'] = ((90..85800).include?(Time.parse(sale['end'].to_s) - Time.parse('12:00 AM')) ? 'Sold Out' : 'Ended')
          end

          sale['status'] ||= DEFAULT_STATUS

          if sale['status'] != DEFAULT_STATUS
            sale.merge!({
              'progress'     => nil,
              'purchase_url' => nil,
              'urgent'       => false
            })
          end

          @attributes = sale
        end

        def with_forum_url!(&block)
          if (forum_url = self['forum_url']) &&
            (self['number'].nil? or forum_url.to_s =~ /DiscussionRedirect/i)

            request = EM::HttpRequest.new(forum_url).get
            request.callback do
              body = Nokogiri::HTML(request.response)

              case request.response_header.status
              when 200..299
                self['number'] = ((script_link = body.at('script[@src*="saleid"]')) ? script_link[:src].scan(/\d+$/).first.to_i : nil)
                self['start']  = ((start = body.search('ul.postTopBar').first) ? Time.parse(start.at('span')[:utc]) : nil)
              when 302
                if forum_url.include?('://deals')
                  self['number'] = forum_url.match(/sale\/(\d+)/i)[1].to_i
                else
                  self['number']    = forum_url.match(/wootsaleid=(\d+)/i)[1].to_i
                  self['forum_url'] = response.response_header.location
                end
              end

              yield(self)
            end
          else
            yield(self)
          end
        end
      end
    end

    include ParserMixin

    class << self
      MAXIMUM_TOKEN_LENGTH = 50

      # Use the old script instead of /SaleStats.aspx?wootsaleid=#{number}
      # because the former includes the product thumbnail image.
      SCRIPT_PATH = 'scripts/dynamic.aspx?control=salesummary&saleid=%s'

      def get_index(shop, page, &block)
        request = EM::HttpRequest.new(shop.join("Forums/Default.aspx?p=#{page}")).get
        request.callback do
          body = Nokogiri::HTML(request.response.to_s)

          resources = body.search('div.forumList').inject([]) do |array, item|
            array << new({
              'woot' => {
                'name'   => (name = item.at('h3 a')).inner_html.to_s.strip,
                'images' => {
                  'thumbnail' => (img = item.at('a.lightBox img'))[:src],
                  'detail'    => img.parent[:href]
                }
              },

              'blog_url'     => ((blog = item.at('a[@title=blog]')) ? blog[:href] : nil),
              'forum_url'    => shop.join("Forums/#{name[:href]}").to_s,
              'shop'         => shop.name,
              'start'        => Time.parse(item.at('h4').inner_html.gsub(/<[^>]+>/, '')),
              'wootcast_url' => ((wootcast = item.at('a[@title=wootcast]')) ? wootcast[:href] : nil)
            })
          end

          yield(resources)
        end
      end

      def sale(object, with_stats = false)
        resource = case object
          when Hash
            object
          when Shop, Symbol
            send((shop = Shop.fetch(object)).source, shop)
          when String
            forum({'forum_url' => object, 'woot' => {}})
          else
            raise ArgumentError, 'argument must be a Hash, Shop, Symbol, or String'
        end

        if (resource['status'] != default_status) || with_stats
          resource = script(resource)
        end

        return resource
      end

      def get_forum(sale, &block)
        raise 'argument must be a Sale' unless sale.acts_like?(:sale)

        shop = WootSync::Shop.fetch(sale.shop)

        sale.with_forum_url! do
          request = EM::HttpRequest.new(shop.join(SCRIPT_PATH % sale.attributes['number'])).get
          request.callback do
            sale.update_stats!(request.response)
            yield(sale)
          end
        end
      end

      def get_source(shop, &block)
        request = EM::HttpRequest.new(shop.source_url, :redirects => 1).get
        request.callback do
          sale = WootSync::Parser.send(:"from_#{shop.source}", shop, request.response)

          if sale.finished?
            get_forum(sale, &block)
          else
            yield(sale)
          end
        end
      end

      def get_summary(shop, &block)
        request = EM::HttpRequest.new(shop.join('DefaultMicrosummary.ashx')).get
        request.callback do
          yield(WS::Parser.from_summary(shop, request.response))
        end
      end

      def image_suffixes
        Array(WootSync.config.parser['images'].keys)
      end

      def parse_image_urls(*args)
        paths = args.map do |value|
          case value
          when Array then value
          when Hash  then value.values
          when Pathname, String, URI then Array(value.to_s.split($/))
          end
        end.flatten.compact.uniq

        paths.inject({}) do |hash, string|
          path = string.to_s

          if path.present? && path =~ URI.regexp('http')
            suf = '(%s)' % image_suffixes.join('|')
            ext = '\.(.+)$'

            suffix, = path.downcase.match((string =~ /-#{suf}#{ext}/i) ?
              /(.*)-(.*)#{ext}/i : /^(.*)...#{suf}#{ext}/i).to_a.slice(-2,1)

            hash.store(suffix, path) if suffix.present?
          end

          hash
        end
      end

      def statuses
        Array(WootSync.config.parser['statuses'])
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
        token = string.mb_chars.normalize(:kd).downcase.gsub(/[^\w ]/n, '').gsub(/[ _]+/n, '_').slice(/^_*(.*?)_*$/n, 1).to_s

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

    attr_reader :attributes

    def initialize(hash = {})
      @attributes = hash
      raise 'attributes hash must include a Shop' unless shop.present?
    end

    def [](var)
      attributes[var.to_s]
    end

    def []=(var, value)
      @attributes[var] = value
    end

    def name
      attributes['woot']['name'] rescue ''
    end

    def shop
      name = case (s = attributes['shop'])
        when String, Symbol, WootSync::Shop then s.to_s
        when Hash then s['name']
      end

      WootSync::Shop.fetch(name)
    end

    private

      def method_missing(method, *args)
        self[method] || super
      end
  end
end
