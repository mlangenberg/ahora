require 'faraday'

module Ahora
  module Resource
    attr_writer :document_parser

    def get(url, params = {})
      connection.get do |req|
        set_common_headers(req)
        req.url url, params
      end
    end

    # FIXME test
    def post(url, body)
      connection.post do |req|
        set_common_headers(req)
        req.url url
        req.body = body
      end
    end

    # FIXME test
    def put(url, body)
      connection.put do |req|
        set_common_headers(req)
        req.url url
        req.body = body
      end
    end

    def connection
      conn = Faraday.new(host, :ssl => { :verify => false }) do |builder|
        builder.use Faraday::Response::RaiseError
        extend_middleware(builder)
        builder.adapter Faraday.default_adapter
      end
      conn.headers['User-Agent'] = 'Ahora'
      conn
    end

    # @abstract override to use custom Faraday middleware
    def extend_middleware(builder); end;

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

    def set_common_headers(req)
      req.headers['Content-Type'] = 'application/xml'
      req.headers['Accept'] = 'application/xml'
    end
  end
end