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

    # TOOD test
    def post(url, body)
      connection.post do |req|
        set_common_headers(req)
        req.url url
        req.body = body
      end
    end

    # TOOD test
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

  class RequestLogger < Faraday::Response::Middleware
    def initialize(app, logger)
      super(app)
      @logger = logger || begin
        require 'logger'
        Logger.new(STDOUT)
      end
    end

    def call(env)
      @logger.info "#{env[:method].to_s.upcase} #{env[:url].to_s}"
      @started = Time.now
      super
    end

    def on_complete(env)
      duration = 1000.0 * (Time.now - @started)
      kbytes = env[:body].to_s.length / 1024.0
      @logger.info "--> %d %s %.2fKB (%.1fms)" % [env[:status], HTTP_STATUS_CODES[env[:status]], kbytes, duration]
    end

    # Every standard HTTP code mapped to the appropriate message.
    # Generated with:
    #   curl -s http://www.iana.org/assignments/http-status-codes | \
    #     ruby -ane 'm = /^(\d{3}) +(\S[^\[(]+)/.match($_) and
    #                puts "      #{m[1]}  => \x27#{m[2].strip}x27,"'
    HTTP_STATUS_CODES = {
      100  => 'Continue',
      101  => 'Switching Protocols',
      102  => 'Processing',
      200  => 'OK',
      201  => 'Created',
      202  => 'Accepted',
      203  => 'Non-Authoritative Information',
      204  => 'No Content',
      205  => 'Reset Content',
      206  => 'Partial Content',
      207  => 'Multi-Status',
      226  => 'IM Used',
      300  => 'Multiple Choices',
      301  => 'Moved Permanently',
      302  => 'Found',
      303  => 'See Other',
      304  => 'Not Modified',
      305  => 'Use Proxy',
      306  => 'Reserved',
      307  => 'Temporary Redirect',
      400  => 'Bad Request',
      401  => 'Unauthorized',
      402  => 'Payment Required',
      403  => 'Forbidden',
      404  => 'Not Found',
      405  => 'Method Not Allowed',
      406  => 'Not Acceptable',
      407  => 'Proxy Authentication Required',
      408  => 'Request Timeout',
      409  => 'Conflict',
      410  => 'Gone',
      411  => 'Length Required',
      412  => 'Precondition Failed',
      413  => 'Request Entity Too Large',
      414  => 'Request-URI Too Long',
      415  => 'Unsupported Media Type',
      416  => 'Requested Range Not Satisfiable',
      417  => 'Expectation Failed',
      418  => "I'm a Teapot",
      422  => 'Unprocessable Entity',
      423  => 'Locked',
      424  => 'Failed Dependency',
      426  => 'Upgrade Required',
      500  => 'Internal Server Error',
      501  => 'Not Implemented',
      502  => 'Bad Gateway',
      503  => 'Service Unavailable',
      504  => 'Gateway Timeout',
      505  => 'HTTP Version Not Supported',
      506  => 'Variant Also Negotiates',
      507  => 'Insufficient Storage',
      510  => 'Not Extended',
    }

  end
end