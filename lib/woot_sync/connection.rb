require 'oauth2'

module OAuth2
  class Client
    def get_access_token
      access_token_params = {'client_id' => id, 'client_secret' => secret, 'grant_type' => 'none'}
      response_params     = request(:post, access_token_url, access_token_params)

      OAuth2::AccessToken.new(self, *response_params.values_at('access_token', 'refresh_token', 'expires_in'))
    end
  end
end

module Faraday
  class Request::Logger < Faraday::Middleware
    def call(env)
      WootSync::Base.logger.info "Faraday::#{env[:method].to_s.capitalize}: #{env[:url]}"
      WootSync::Base.logger.info "status: #{env[:status]}"
      @app.call(env)
    end
  end
end

module WootSync
  class ConnectionError < WootSyncException; end

  module Connection
    extend ActiveSupport::Concern

    included do
      cattr_reader :connection

      def config.connection=(hash)
        super(hash.reverse_merge(self.connection || {}))

        options = {:headers => {}}

        api_host, site_host, user_agent = self.connection.values_at('api_host', 'site_host', 'user_agent')

        unless user_agent.blank?
          parts = {'lib' => "WootSync/#{VERSION::STRING}", 'host' => site_host}
          options[:headers]['User-Agent'] = (RUBY_VERSION >= '1.9') ? user_agent % parts : begin
            user_agent.gsub(/%\{([^\}]+)\}/, '%s') % user_agent.scan(/%\{([^\}]+)\}/).flatten.map { |k| parts[k] }
          end
        end

        options[:builder] = Faraday::Builder.new do |b|
          b.adapter Faraday.default_adapter
          b.use Faraday::Request::Logger
        end

        connection = Faraday::Connection.new(options)
        Base.send(:class_variable_set, :@@connection, connection)
      end
    end

    module ClassMethods
      delegate *(Faraday::Connection::METHODS.to_a + [{:to => :connection}])
      delegate :build_url, :url_prefix=, :to => :'client.client.connection'

      def api_host
        (s = config.connection['api_host'].to_s.strip).present? ? s : config.connection['site_host']
      end

      def client
        @token ||= begin
          id, secret = config.connection['credentials']

          client = OAuth2::Client.new(id, secret, {:site => api_host, :parse_json => true})
          client.get_access_token
        end
      end

      def request(url, &block)
        yield get(url)
      rescue SocketError
        raise ConnectionError, "#{$!.class}: #{$!}"
      end

      def save(sale)
        method = :put

        sale_save_url = sale['url'] || begin
          method   = :post
          woot_url = begin
            client.post('woots.json', {'woot' => sale.delete('woot')})['url']
          rescue OAuth2::HTTPError
            $!.message.include?('304') ? $!.response.headers['content-location'] : raise
          end

          "#{woot_url.chomp('.json')}/sales"
        end

        begin
          client.send(method, "#{sale_save_url.chomp('.json')}.json", {'sale' => sale})
        rescue OAuth2::HTTPError
          if $!.message.include?('304')
            client.get($!.response.headers['content-location'])
          else
            raise
          end
        end
      end

      def today
        Array(client.get('sales/today.json')).inject({}) do |h,a|
          h.store(a['shop'], a) unless a.blank?; h
        end
      end

      def user_agent
        connection.headers['User-Agent']
      end
    end
  end
end
