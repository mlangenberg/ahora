require 'minitest/autorun'
require 'minitest/pride'
require 'fakeweb'
require_relative '../test_helper'
require_relative '../../lib/ahora/resource'

FakeWeb.allow_net_connect = false

class DefaultPost
  include Ahora::Resource

  def host
    'http://test.net/'
  end
end

class CustomPost < DefaultPost
  def headers
    super.update \
      'Accept' => 'text/plain',
      'X-Custom' => 'foobar'
  end

  def extend_middleware builder
    builder.adapter :rack
  end
end

describe 'default headers' do
  before do
    @default = DefaultPost.new.connection.headers
    @custom = CustomPost.new.connection.headers
  end

  it 'includes the user agent, accept and content-type' do
    @default['User-Agent'].must_equal 'Ahora'
    @default['Accept'].must_equal 'application/xml'
    @default['Content-Type'].must_equal 'application/xml'
  end

  it 'allows overriding and setting custom headers' do
    @custom['User-Agent'].must_equal 'Ahora'
    @custom['Accept'].must_equal 'text/plain'
    @custom['Content-Type'].must_equal 'application/xml'
    @custom['X-Custom'].must_equal 'foobar'
  end
end

describe 'connection adapter' do
  it 'includes the default Faraday adapter' do
    faraday = DefaultPost.new.connection
    adapter = faraday.builder.handlers.last
    adapter.klass.ancestors.must_include Faraday::Adapter
  end

  it 'can configure a custom Faraday adapter' do
    faraday = CustomPost.new.connection
    adapter = faraday.builder.handlers.last
    adapter.klass.must_equal Faraday::Adapter::Rack
  end
end

describe '#put' do
  before do
    @post = DefaultPost.new
  end

  it "supports passing an url and a body" do
    FakeWeb.register_uri :put, 'http://test.net/posts', :body => 'body'
    @post.put("posts", "body").body.must_equal 'body'
  end

  it "supports passing an url and a params hash" do
    FakeWeb.register_uri :put, 'http://test.net/posts?foo=bar', :body => 'param'
    @post.put("posts") { |req|
      req.params[:foo] = 'bar'
    }.body.must_equal 'param'
  end
end
