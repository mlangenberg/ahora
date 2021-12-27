require 'faraday'

module Ahora
  module Resource
    attr_writer :document_parser

    def get(url, params = nil)
      begin
        connection.run_request(:get, url, nil, nil) do |req|
          req.params.update(params) if params
          yield req if block_given?
        end
      rescue => e
        handle_exception(e)
      end
    end

    # FIXME test
    def post(url, body = nil)
      begin
        connection.run_request(:post, url, body, nil) do |req|
          yield req if block_given?
        end
      rescue => e
        handle_exception(e)
      end
    end

    # FIXME test
    def put(url, body = nil)
      begin
        connection.run_request(:put, url, body, nil) do |req|
          yield req if block_given?
        end
      rescue => e
        handle_exception(e)
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
      instantiator, response = extract_parser_from_args(*args, &block)
      Collection.new instantiator, document_parser, response
    end

    def single(*args, &block)
      instantiator, response = extract_parser_from_args(*args, &block)
      Response.new instantiator, document_parser, response
    end

    private

    def extract_parser_from_args(*args, &block)
      if args.size == 2
        klass, response = args
        instantiator = lambda do |doc|
          klass.parse(doc)
        end
      else
        response = args.first
        instantiator = block
      end
      [instantiator, response]
    end

    def document_parser
      @document_parser ||= XmlParser.method(:parse)
    end

    def connection_options
      (defined?(super) ? super.dup : {}).update \
        :headers => headers
    end

    def handle_exception(e)
      case e
      when Faraday::TimeoutError, Faraday::ConnectionFailed
        e.extend Ahora::Error::TimeoutError
      else
        e.extend Ahora::Error::ClientError
      end
      raise
    end

  end
end
