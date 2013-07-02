require 'faraday'

module Ahora
  module Resource
    attr_writer :document_parser

    def get(url, params = nil)
      connection.run_request(:get, url, nil, nil) do |req|
        req.params.update(params) if params
        yield req if block_given?
      end
    end

    # FIXME test
    def post(url, body = nil)
      connection.run_request(:post, url, body, nil) do |req|
        yield req if block_given?
      end
    end

    # FIXME test
    def put(url, body = nil)
      connection.run_request(:put, url, body, nil) do |req|
        yield req if block_given?
      end
    end

    def connection
      Faraday.new(host.dup, connection_options) do |conn|
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
