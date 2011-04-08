require 'active_support/core_ext/hash/reverse_merge'
require 'em-http'

module EventMachine
  module Middleware
    class JSONResponse
      def response(resp)
        begin
          body = ActiveSupport::JSON.decode(resp.response)
          resp.response = body
        rescue Exception => e
        end
      end
    end

    class Logger
      def request(client, head, body)
        WootSync.logger.info "#{client.req.method.upcase} #{client.req.uri}"
        [head, body]
      end

      def response(resp)
        WootSync.logger.info "status: #{resp.response_header.status}"
      end
    end

    class UserAgent
      def self.request(head, body)
        [head.merge({'user-agent' => WootSync::Client.user_agent}), body]
      end
    end
  end
end

EM::HttpRequest.use EM::Middleware::UserAgent

module WootSync
  class Client

    API_FORMAT = :json

    class << self
      def run(&block)
        EM::run do
          EM::HttpRequest.use EM::Middleware::Logger
          new.callback(&block)
        end
      end

      def user_agent
        WootSync.config.user_agent ||= begin
          user_agent, site_host = WootSync.config.client.values_at('user_agent', 'site_host')

          parts = {'lib' => "#{WootSync.name}/#{VERSION::STRING}", 'host' => site_host}

          (RUBY_VERSION >= '1.9') ? user_agent % parts : begin
            user_agent.gsub(/%\{([^\}]+)\}/, '%s') % user_agent.scan(/%\{([^\}]+)\}/).flatten.map { |k| parts[k] }
          end
        end
      end
    end

    include EM::Deferrable

    attr_accessor :headers, :host

    def initialize
      @host = (WootSync.config.client['api_host'] || WootSync.config.client['site_host'])

      access_grant = {'grant_type' => 'none'}
      access_grant['client_id'], access_grant['client_secret'] = WootSync.config.client['credentials']

      result = new_request.post(:path => 'oauth/access_token', :body => access_grant)
      result.callback do
        @headers = {'Authorization' => "OAuth #{result.response['access_token']}"}
        succeed(self)
      end

      result.errback { fail }
    end

    EM::HTTPMethods.public_instance_methods.each do |method|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{method}(*args)
          new_request.send(:#{method}, *args_with_auth(args))
        end
      RUBY_EVAL
    end

    def save(object, &block)
      raise 'argument must be a Sale' unless object.acts_like?(:sale)

      sale = object.attributes
      woot = sale.delete('woot')

      woot_post = post(:path => url_to_path('woots'), :body => {'woot' => woot}, :keepalive => true)
      woot_post.callback do
        method, path = begin
          if sale.include?('url')
            [:put, url_to_path(sale['url'])]
          else
            [:post, url_to_path(woot_post.response_header['LOCATION'], 'sales')]
          end
        end

        sale_save = send(method, :path => path, :body => {'sale', sale}, :keepalive => true)
        sale_save.callback do
          sale_get = get(:path => url_to_path(sale_save.response_header['LOCATION']))
          sale_get.callback do
            yield(sale_get.response)
          end
        end
      end
    end

    def today(&block)
      get(:path => url_to_path('sales/today')).callback do |result|
        yield(result.response.inject(Hash.new({})) { |h,r| h.store(r['shop']['name'], r); h })
      end
    end

    private

      def args_with_auth(args = [])
        options = args.extract_options!
        options[:head] ||= {}
        options[:head].reverse_merge!(headers)

        args << options
      end

      def new_request
        request = EM::HttpRequest.new(host)
        request.use EM::Middleware::JSONResponse

        return request
      end

      def url_to_path(string, file = '')
        string.chomp('.json').scan(/^(#{host})?(.+)$/).flatten.last.to_s + (file.present? ? "/#{file}" : '') + ".#{API_FORMAT}"
      end
  end
end
