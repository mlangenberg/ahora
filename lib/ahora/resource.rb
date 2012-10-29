require 'faraday'

module Ahora
  module Resource
    attr_writer :document_parser

    def get(url, params = {})
      connection.get do |req|
        req.url url, params
      end
    end

    # FIXME test
    def post(url, body)
      connection.post do |req|
        req.url url
        req.body = body
      end
    end

    # FIXME test
    def put(url, body_or_params)
      body, params = body_or_params.is_a?(Hash) ? [nil, body_or_params] : [body_or_params, nil]
      connection.put do |req|
        req.url url, params
        req.body = body
      end
    end

    def connection
      Faraday.new(host, connection_options) do |conn|
        conn.use Faraday::Response::RaiseError
        extend_middleware(conn.builder)
        unless conn.builder.handlers.any? {|mid| mid.klass < Faraday::Adapter }
          conn.adapter Faraday.default_adapter
        end
      end
    end

    # @abstract override to use custom Faraday middleware
    def extend_middleware(builder)
      super if defined? super
    end

    # FIXME test (FakeWeb cannot test request headers)
    # @abstract override to set custome headers
    # returns a hash with a string for each key
    def headers
      (defined?(super) ? super.dup : {}).update \
        :user_agent   => 'Ahora',
        :content_type => 'application/xml',
        :accept       => 'application/xml'
    end

    def collection(*args, &block)
      if args.size == 2
        klass, response = args
        instantiator = lambda do |doc|
          klass.parse(doc)
        end
      else
        response = args.first
        instantiator = block
      end
      Collection.new instantiator, document_parser, response
    end

    private
    def document_parser
      @document_parser ||= XmlParser.method(:parse)
    end

    def connection_options
      (defined?(super) ? super.dup : {}).update \
        :headers => headers
    end
  end
end
