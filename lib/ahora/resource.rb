require 'faraday'

module Ahora
  module Resource
    attr_writer :document_parser

    def get(url, params = {})
      response = connection.get do |req|
        req.url url, params
      end
      response
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
    def extend_middleware; end;

    def collection(klass, response)
      Collection.new klass, document_parser, response
    end

    private
    def document_parser
      @document_parser ||= XmlParser.method(:parse)
    end
  end

  class LastModifiedCaching < Faraday::Middleware
    attr_reader :cache

    extend Forwardable
    def_delegators :'Faraday::Utils', :parse_query, :build_query

    # Public: initialize the middleware.
    #
    # cache   - An object that responds to read, write and fetch (default: nil).
    # options - An options Hash (default: {}):
    #           :ignore_params - String name or Array names of query params
    #                            that should be ignored when forming the cache
    #                            key (default: []).
    #
    # Yields if no cache is given. The block should return a cache object.
    def initialize(app, cache = nil, options = {})
      super(app)
      options, cache = cache, nil if cache.is_a? Hash and block_given?
      @cache = cache || yield
      @options = options
    end

    def call(env)
      if env[:method] == :get

        timestamp_key = cache_key(env) + ':timestamp'
        data_key      = cache_key(env) + ':response'

        if date = cache.read(timestamp_key) # WARN FakeWeb cannot test this
          env[:request_headers]['if-modified-since'] = date
        end

        response = @app.call(env)

        if response.status == 304
          response = cache.read data_key
        elsif date = response.headers['last-modified']
          cache.write timestamp_key, date
          cache.write data_key, response
        end

        finalize_response(response, env)
      else
        @app.call(env)
      end
    end

    def cache_key(env)
      url = env[:url].dup
      if url.query && params_to_ignore.any?
        params = parse_query url.query
        params.reject! {|k,| params_to_ignore.include? k }
        url.query = build_query params
      end
      url.normalize!
      url.request_uri
    end

    def params_to_ignore
      @params_to_ignore ||= Array(@options[:ignore_params]).map { |p| p.to_s }
    end

    def finalize_response(response, env)
      response = response.dup if response.frozen?
      env[:response] = response
      unless env[:response_headers]
        env.update response.env
        # FIXME: omg hax
        response.instance_variable_set('@env', env)
      end
      response
    end

  end
end