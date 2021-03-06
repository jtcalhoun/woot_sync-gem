require 'active_support/core_ext/hash/reverse_merge'
require 'em-http'
require 'em-http/middleware/json_response'

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

module WootSync
  class Client

    class ClientError < WootSync::Exception; end
    class ClientRefused < ClientError; end
    class ClientTimedOut < ClientError; end

    class << self
      def run(*args, &block)
        client = new(*args)

        EM::HttpRequest.use(EM::Middleware::Logger)

        if EM.reactor_running?
          client.authorize(&block)
        else
          EM.run(client.method(:authorize).to_proc(&block))
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

    attr_accessor :access_token, :host

    def initialize(host = nil)
      @host  = host || (WootSync.config.client['api_host'] || WootSync.config.client['site_host'])
    end

    EM::HTTPMethods.public_instance_methods.each do |method|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{method}(*args, &block)
          request(:#{method}, *args, &block)
        end
      RUBY_EVAL
    end

    private

      def authorize(&block)
        access_grant = {'grant_type' => 'none'}
        access_grant['client_id'], access_grant['client_secret'] = WootSync.config.client['credentials']

        callback = proc do |request|
          @access_token = request.response["access_token"]
          yield(self)
        end

        post("oauth/access_token", :body => access_grant, &callback)
      end

      def errback
        proc do |http|
          klass, message = catch :error do
            if http.error == Errno::ETIMEDOUT
              throw :error, [ClientTimedOut, "The connection to %s has timed out."]
            elsif http.error == Errno::ECONNREFUSED
              throw :error, [ClientRefused, "The connection to %s was refused."]
            else
              throw :error, [ClientError, "An unknown error occurred while connecting to %s."]
            end
          end

          raise klass, message % http.req.uri
        end
      end

      def request(method, uri, *args, &block)
        uri  = URI.join(self.host, uri.to_s)
        http = EventMachine::HttpRequest.new(uri.to_s, :inactivity_timeout => 30)

        http.use(EM::Middleware::UserAgent)

        options = args.extract_options!

        if uri.host == URI.parse(self.host).host
          http.use(EventMachine::Middleware::JSONResponse)

          options[:head] ||= {}
          options[:head].reverse_merge!({'Authorization' => "OAuth #{access_token}"}) if access_token.present?
        end

        response = http.send(method, options)

        response.errback(&errback)
        response.callback do |request|
          case request.response_header.status
          when 200..201, 301..303
            yield(request)
          when 304
            get(request.response_header.location, &block)
          when 422, 500
            yield(nil)
          else
            errback.call(request)
          end
        end
      end
  end
end
