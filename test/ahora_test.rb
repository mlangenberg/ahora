
require 'fakeweb'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/ahora'

FakeWeb.allow_net_connect = false


def fake_http(path, body)
  FakeWeb.register_uri :get, uri(path), :body => body
end

def uri(path)
  'http://user:pass@test.net' + path
end

def fixture(name)
  File.open File.join(File.dirname('__FILE__'), 'test', 'fixtures', "#{name}.xml")
end

require 'singleton'
class MemCache
  include Singleton
  def initialize
    @store = {}
  end

  def read(key)
    @store[key]
  end

  def write(key, value, options = {})
    @store[key] = value
  end
end

class PostRepository
  include Ahora::Resource
  USERNAME = 'user'
  PASSWORD = 'pass'

  def find_by_user_id(id)
    collection Post, get("/users/#{id}/posts.xml")
  end

  def extend_middleware(builder)
    builder.use Faraday::Request::BasicAuthentication, USERNAME, PASSWORD
    builder.use Ahora::LastModifiedCaching, MemCache.instance
  end

  def host
    'http://test.net/'
  end
end

class Post < Ahora::Representation
  objectid :id, :user_id, :parent_id
  date  :created_at
  element :body
  element 'user', :with => Ahora::Representation do
    string :first_name, :last_name
  end
  elements 'replies/userPost' => :replies, :with => Post
end


describe "requesting a collection" do
  before do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    @posts = PostRepository.new.find_by_user_id(1)
  end

  it "has the right size" do
    @posts.size.must_equal 1
  end

  it "has a cache key" do
    @posts.cache_key.must_equal 'http://test.net/users/1/posts.xml'
  end

  describe "a single post from the collection" do
    subject { @posts.first }

    it "has the right body" do
      subject.body.must_equal "How is everybody today?"
    end

    it "renames foreign element names and converts integers" do
      subject.id.must_equal 1
      subject.user_id.must_equal 1
    end

    it "must handle date conversion" do
      subject.created_at.must_equal Date.parse("2011-10-26T17:01:52+02:00")
    end

    it "handles nested resources" do
      subject.user.first_name.must_equal "John"
    end

    it "handles nested collection resources" do
      subject.replies.size.must_equal 2
    end

    describe "a single reply" do
      let(:reply) { subject.replies.first }

      it "behaves the same as a single post" do
        reply.id.must_equal 2
        reply.user_id.must_equal 2
        reply.parent_id.must_equal 1
        reply.user.last_name.must_equal "Smith"
      end
    end
  end
end

describe 'requesting a collection with if-modified-since support' do
  before do
    FakeWeb.register_uri :get, uri('/users/1/posts.xml'), [
      { :body => fixture('user_posts'), 'Last-Modified' => 'Mon, 02 Apr 2012 15:20:41 GMT' },
      { :body => nil, :status => [304, 'Not Modified'] }
    ]
    @repository = PostRepository.new
  end

  it "caches when response header includes Last-Modified" do
    @repository.find_by_user_id(1).size.must_equal(1)
    @posts = @repository.find_by_user_id(1).size.must_equal(1)
  end
end

describe 'lazy loading' do
  before do
    @repository = PostRepository.new
    @repository.document_parser = -> body { raise('NotLazyEnough') }
  end

  it "should not parse the response if not necessary" do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    @posts = PostRepository.new.find_by_user_id(1)
  end
end

describe "creating a new instance" do
  it "allows to create a new instance with an attribute hash" do
    p = Post.new :body => 'hi'
    p.body.must_equal 'hi'
  end
end