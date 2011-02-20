require 'nokogiri'

module WootSync
  class ParseError < WootSyncException; end

  module Parser
    extend ActiveSupport::Concern

    module ClassMethods

      def default_status
        statuses.first
      end

      def statuses
        Array(config.parser['statuses'])
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

      def sales(page)
        request(shop.join("Forums/Default.aspx?p=#{page}")) do |response|
          resources = response.search('div.forumList').inject([]) do |r, item|
            r << {
              'woot' => {
                'name'   => (name = item.at('h3 a')).inner_html.to_s.strip,
                'images' => {
                  'thumbnail' => (img = response.at('a.lightBox img'))[:src],
                  'detail'    => img.parent[:href]
                }
              },

              'blog_url'     => ((blog = item.at('a[@title=blog]')) ? blog[:href] : nil),
              'forum_url'    => URI.join(response.uri.to_s, name[:href]).to_s,
              'shop'         => shop.name,
              'start'        => Time.parse(item.at('h4').inner_html.gsub(/<[^>]+>/, '')),
              'wootcast_url' => ((wootcast = item.at('a[@title=wootcast]')) ? wootcast[:href] : nil)
            }
          end

          return Array(resources)
        end
      end

      def summary(shop)
        request(shop.join('DefaultMicrosummary.ashx')) do |response|
          parts = response.body.to_s.strip.split(' : ')
          parts.map! { |r| r.strip if r.kind_of?(String) }

          raise ParseError, "Microsummary data is malformed." if parts.empty?

          keys = begin
            if parts[0] =~ /.*%$/
              {'progress' => 0, 'price' => 1, 'name' => 2, 'status' => 3}
            else
              {'price' => 0, 'name' => 1, 'status' => 2}
            end
          end

          parts[keys['price']]    = parts[keys['price']].to_s.match(/^\$?(.*)$/)[1].to_f
          parts[keys['progress']] = parts[keys['progress']].to_s.match(/(\d*)%?/)[1].to_i if keys['progress']

          parts[keys['status']] ||= default_status

          resource = {'woot' => {'name' => parts[keys.delete('name')]}, 'shop' => shop.name}
          resource.merge!(keys.inject({}) { |h,(k,v)| h.store(k, parts[v]); h })

          return resource
        end
      end

      private

        def forum(sale)
          if (forum_url = sale['forum_url']) &&
            (sale['number'].nil? or forum_url.to_s =~ /DiscussionRedirect/i)

            request(forum_url) do |response|
              body = Nokogiri::HTML(response.body)

              if response.success?
                sale.merge!({
                  'number' => ((script_link = body.at('script[@src*="saleid"]')) ? script_link[:src].scan(/\d+$/).first.to_i : nil),
                  'start'  => ((start = body.search('ul.postTopBar').first) ? Time.parse(start.at('span')[:utc]) : nil)
                })
              elsif response.status == 302
                if forum_url.include?('://deals')
                  sale.merge!({
                    'number' => forum_url.match(/sale\/(\d+)/i)[1].to_i
                  })
                else
                  sale.merge!({
                    'forum_url' => response.headers['location'],
                    'number'    => forum_url.match(/wootsaleid=(\d+)/i)[1].to_i
                  })
                end
              end
            end
          end

          return sale
        end

        def homepage(shop)
          request("#{shop.host}/") do |response|
            raise ParseError, "Unable to parse Sale info from SaleRSS." if response.body.empty?

            body = Nokogiri::HTML(response.body)

            sale = {
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
                  'detail'   => body.at('img.photo').parent[:href],
                  'standard' => body.at('img.photo')[:src]
                }
              },

              'condition'   => body.at('div.productDescription dd').inner_html.to_s.strip,
              'description' => body.at('div.writeUp').inner_html.to_s.strip,
              'forum_url'   => ((forum_url = body.at('li.discuss a')) ? forum_url[:href] : nil),
              'launch'      => !body.at("div[@id$=LaunchPanel]").nil?,
              'number'      => ((m = response.body.match(/wootsaleid=(\d+)/i)).nil? ? nil : m[1].to_i),
              'price'       => body.at('div.productDescription span.amount').inner_html.to_s.match(/^\$?(.*)$/)[1],
              'shipping'    => body.at('ul#shippingOptions li').inner_html,
              'shop'        => shop.name,
              'title'       => body.at('div.story h2').inner_html.to_s.strip,
              # 'wootoff'     => !body.at('.wootOff').nil?
            }

            sale['status'], sale['purchase_url'] = begin
              case (link = body.at('a[@id$=HyperLinkWantOne]'))[:class].to_s
              when /soldOut/i
                'Sold Out'
              else
                sale['urgent'] = link[:class].to_s.include?('urgent')
                [default_status, (link[:href].empty? ? nil : link[:href].to_s)]
              end
            end

            if progress = body.at('div[@id$=ProgressBar]')
              sale['progress'] = progress.at('div.wootOffProgressBarValue')[:style].scan(/width: ?(\d+)%/i).first.first.to_i
            end

            return script(sale, false)
          end
        end

        def salerss(shop)
          host = URI.parse(shop.host).host
          request("http://api.woot.com/1/sales/current.rss/#{host}") do |response|
            body = Nokogiri::XML(response.body).remove_namespaces!
            item = body.at('item')

            raise ParseError, "Unable to parse Sale info from SaleRSS." if item.nil?

            sale = {
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
              'status'       => ((item.at('soldout').inner_html.downcase.eql?('true') && 'Sold Out') || Base.default_status),
              'title'        => item.at('subtitle').inner_html,
              'wootcast_url' => ((enclosure = item.at('enclosure')) ? enclosure[:url] : nil),
              'wootoff'      => (item.at('wootoff').inner_html.to_s.downcase == 'true')
            }

            sale['start'] = Time.parse((sale['wootoff'] ? body.at('rss/channel/pubDate') : item.at('pubDate')).inner_html.chomp('GMT'))

            return sale
          end
        end

        def script(sale, with_stats = true)

          # Ensure that we have the number for this Sale.
          sale = forum(sale)

          # Use the old script instead of /SaleStats.aspx?wootsaleid=#{number}
          # because the former includes the product thumbnail image.
          request(WootSync::Shop[sale['shop']].join("scripts/dynamic.aspx?control=salesummary&saleid=#{sale['number']}")) do |response|

            body = Nokogiri::HTML(response.body.strip.gsub('\"', '"').match(/^document\.write\(["'] *(.*) *["']\);/)[1])

            # Remove the improperly nested <div> in the Shirt sale attributes.
            if invalid_div = body.at('.saleStats-thread')
              body = Nokogiri::HTML(body.to_s.gsub("</dl>#{invalid_div.to_s}", ''))
            end

            sale['woot'] ||= {}; s = Hash.new

            if (img = body.at('.thumbnail'))
              sale['woot']['images'] ||= {}
              sale['woot']['images'].reverse_merge!({
                'thumbnail' => img[:src],
                'detail'    => img.parent[:href]
              })
            end

            if (a = body.at('a#HyperLinkTitle'))
              s['wootcast_title'] = a.inner_html
              s['wootcast_url']   = a[:href]
            end

            if (dl = body.at('dl[@class=itemSummary]'))

              sale['woot']['name'] ||= ((dt = dl.at('dt')) ? (dt.at('a') || dt).inner_html : nil)
              s['blog_url'] = ((a2 = dl.at('dt a')) ? a2[:href] : nil)

              if with_stats
                first_speed = nil

                dl.search('dd').each do |dd|
                  next unless dd.inner_html =~ /[\r\n\t ]*([^>]+): *(.*)/i

                  case (fields = dd.inner_html.split(':', 2).map{ |f| f.strip }).first.downcase

                  when /blame|last wooter/
                    sale['blame'] = fields.last
                    s['status']   = 'Sold Out' if fields.first =~ /sellout/i
                    # s[:status]   = 'Ended' if fields.first =~ /last wooter/i

                  when /pace/
                    order_pace  = fields.last.match(/(([0-9\.]+)h)? *(([0-9\.]+)m)? *(([0-9\.]+)s)?/i)
                    sale['pace'] = (order_pace[2].to_f * 3600) + (order_pace[4].to_f * 60) + (order_pace[6].to_f)

                  when /(quantity|woots sold|total woots)/
                    sale['quantity'] = fields.last.to_i
                    s['status']      = 'Sold Out' if fields.first =~ /total woots/i

                  when /(sellout time|last purchase time)/
                    s['end'] = fields.last

                    if fields.first =~ /sellout time/i
                      s['status']    = 'Sold Out'
                      sale_finished = true
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
            end

            sale.merge!(s)

            if with_stats
              (labels = %w(one two three)).each do |label|
                begin
                  bought_label = "bought_#{label}"
                  sale.store(bought_label, (body.to_s.match(/(\d+)% +bought +#{labels.index(label) + 1}/i)[1].to_i / 100.0))
                rescue NoMethodError
                  # Do nothing.
                end
              end

              # If sale[:end] is greater than 00:01:30 and less than 23:50:00,
              # assume that the Sale has Sold Out. Otherwise assume that it
              # has Ended. This may prove inaccurate for some Wootoff Sales,
              # but these should be resolved server-side.
              if !(sale_finished ||= false) and !sale['end'].nil?
                sale['status'] = ((90..85800).include?(Time.parse(sale['end'].to_s) - Time.parse('12:00 AM')) ? 'Sold Out' : 'Ended')
              end

              if sale['status'] != default_status
                sale.merge!({
                  'progress'     => nil,
                  'purchase_url' => nil,
                  'urgent'       => false
                })
              end
            end

            return sale
          end
        end
    end
  end
end
