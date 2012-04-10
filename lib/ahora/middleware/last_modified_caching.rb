module Ahora
  module Middleware
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
      #           :cache_header  - String name of response header that should be
      #                            used to retrieve cache timestamp from.
      #                            Defaults to 'last-modified'
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

          if date = cache.read(timestamp_key)
            # WARN FakeWeb cannot test this
            env[:request_headers]['If-Modified-Since'] = Time.parse(date).httpdate
          end

          response = @app.call(env)

          if response.status == 304
            response = cache.read data_key
          elsif date = response.headers[@options[:cache_header] || 'Last-Modified']
            response.env[:cache_key] = fragment_cache_key(env, date)
            cache.write timestamp_key, date
            cache.write data_key, response
          end

          finalize_response(response, env)
        else
          @app.call(env)
        end
      end

      def fragment_cache_key(env, last_modified)
        cache_key(env) + ":fragment_#{last_modified}"
      end

      def cache_key(env)
        url = env[:url].dup
        if url.query && params_to_ignore.any?
          params = parse_query url.query
          params.reject! {|k,| params_to_ignore.include? k }
          url.query = build_query params
        end
        url.normalize!
        url.to_s
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
end
