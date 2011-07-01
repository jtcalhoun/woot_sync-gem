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

    class ClientError < WootSync::Exception; end
    class RecordInvalid < ClientError; end

    class ServerError < WootSync::Exception; end

    class << self
      def run(host = nil, &block)
        EM::run do
          EM::HttpRequest.use EM::Middleware::Logger
          new(host).callback(&block)
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

    attr_accessor :access_token, :host, :queue

    def initialize(host = nil)
      @queue = EM::Queue.new
      @host  = host || (WootSync.config.client['api_host'] || WootSync.config.client['site_host'])

      authorize { succeed(self) }
    end

    def request(method, url, body = nil, &block)
      server = raw_request.send(method, args_with_auth(:path => url_to_path(url), :body => body))
      server.callback do
        case server.response_header.status
        when 200, 201
          yield(WootSync::Sale.new(server.response))
        when 304
          get(server.response_header.location, nil, &block)
        when 401
          queue.push([method, url, body, block])
          authorize(&self.method(:empty_queue).to_proc) unless queue.size > 1
        when 422
          yield(RecordInvalid.new("Validation failed: #{server.response['errors'].join(', ')}"))
        when 500
          yield(ServerError.new("Internal Server Error"))
        end
      end

      server.errback do
        yield(ServerError.new('Connection to remote server failed.'))
      end
    end

    EM::HTTPMethods.public_instance_methods.each do |method|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{method}(*args, &block)
          request(:#{method}, *args, &block)
        end
      RUBY_EVAL
    end

    def today(&block)
      server = raw_request.get(args_with_auth(:path => url_to_path('sales')))
      hash   = Hash.new({})

      server.callback do
        if server.response
          hash = server.response.inject(hash) do |h,r|
            h.store(r['shop']['name'], r) unless r.nil?; h
          end
        end

        yield(hash)
      end

      server.errback do
        WootSync.logger.warn 'Could not retrieve latest Sale records.'
        yield(hash)
      end
    end

    private

      def authorize(&block)
        access_grant = {'grant_type' => 'none'}
        access_grant['client_id'], access_grant['client_secret'] = WootSync.config.client['credentials']

        server = raw_request.post(:path => 'oauth/access_token', :body => access_grant)
        server.callback do
          @access_token = server.response['access_token']
          yield
        end

        server.errback do
          WootSync.logger.error 'Access token request failed.'
          EM::add_timer(20, proc { authorize(&block) })
        end
      end

      def raw_request(*args)
        request = EM::HttpRequest.new(host, *args)
        request.use EM::Middleware::JSONResponse

        return request
      end

      def url_to_path(string, file = '')
        string.chomp('.json').scan(/^(#{host})?(.+)$/).flatten.last.to_s + (file.present? ? "/#{file}" : '') + ".#{API_FORMAT}"
      end

      def args_with_auth(*args)
        options = args.extract_options!
        options[:head] ||= {}
        options[:head].reverse_merge!({'Authorization' => "OAuth #{access_token}"})

        return options
      end

      def empty_queue
        continue = proc do |args|
          block = args.pop

          request(*args, &block)
          queue.pop(&continue)
        end

        queue.pop(&continue)
      end
  end
end
