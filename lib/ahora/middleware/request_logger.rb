module Ahora
  module Middleware
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
end