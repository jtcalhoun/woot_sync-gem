require 'active_support/core_ext/hash/reverse_merge'
require 'em-http'

module EventMachine
  module HttpEncoding
    def escape(s)
      URI.encode_www_form_component(s)
    end

    def unescape(s)
      URI.decode_www_form_component(s)
    end
  end

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

          parts = {:lib => "#{WootSync.name}/#{VERSION::STRING}", :host => site_host}

          user_agent % parts
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

    def sale(url, &block)
      get(:path => url_to_path(url)).callback do |result|
        yield(result.response)
      end
    end

    def today(&block)
      get(:path => url_to_path('sales')).callback do |result|
        hash = result.response.inject(Hash.new({})) do |h,r|
          h.store(r['shop']['name'], r) unless r.nil?; h
        end

        yield(hash)
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
