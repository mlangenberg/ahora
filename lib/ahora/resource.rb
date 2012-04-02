require 'faraday'

module Ahora
  module Resource
    USERNAME = 'user'
    PASSWORD = 'pass'
    HOST      = 'http://test.net/'

    def get(url, params = {})
      response = connection.get do |req|
        req.url url, params
      end
      response
    end

    def connection
      conn = Faraday.new(HOST, :ssl => { :verify => false }) do |builder|
        builder.use Faraday::Request::BasicAuthentication, USERNAME, PASSWORD
        builder.use Faraday::Response::RaiseError
        builder.adapter Faraday.default_adapter
      end
      conn.headers['User-Agent'] = 'Ahora'
      conn
    end
  end
end