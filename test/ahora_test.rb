require 'fakeweb'
require 'minitest/autorun'
require 'minitest/pride'
require_relative 'test_helper'
require_relative '../lib/ahora'

FakeWeb.allow_net_connect = false

require 'singleton'
class MemCache
  include Singleton
  def initialize
    @store = {}
  end

  def read(key)
    @store[key] ? Marshal.load(@store[key]) : nil
  end

  def write(key, value, options = {})
    @store[key] = Marshal.dump(value)
  end
end

class PostRepository
  include Ahora::Resource
  USERNAME = 'user'
  PASSWORD = 'pass'

  def find_by_user_id(id)
    collection Post, get("/users/#{id}/posts.xml")
  end

  def find_by_user_id_and_post_id(user_id, id)
    single PostDomain, get("/users/#{user_id}/posts/#{id}.xml")
  end

  def extend_middleware(builder)
    builder.use Faraday::Request::BasicAuthentication, USERNAME, PASSWORD
    builder.use Ahora::Middleware::LastModifiedCaching, MemCache.instance
  end

  def host
    'http://test.net/'
  end
end

class Post < Ahora::Representation
  def self.attribute_selector(name)
    "./#{name.to_s.gsub(/_([a-z])/){ $1.upcase }}"
  end

  def self.base_parser_class
    Post
  end

  element './objectId' => :id, :with => lambda {|n| n.content.to_i }
  element './userObjectId' => :user_id, :with => lambda {|n| n.content.to_i }
  element './parentObjectId' => :parent_id, :with => lambda {|n| n.content.to_i }
  date  :created_at
  element :body
  element 'user' do
    string :first_name, :last_name
  end
  boolean :hidden
  elements 'replies/userPost' => :replies, :with => self
end

class PostDomainRepository < PostRepository
  def find_by_user_id(id)
    collection PostDomain, get("/users/#{id}/posts.xml")
  end
end

class PostDomain < DelegateClass(Post)
  def self.parse(doc)
    post = Post.parse(doc)
    post.hidden? ? nil : new(post)
  end

  def initialize(post)
    super(post)
  end

  def published?
    created_at < Date.today
  end
end

class BlogPostRepository < PostRepository
  include Ahora::Resource

  def all
    collection get("/users/1/posts.xml") do |doc|
      Post.parse(doc)
    end
  end
end

describe "requesting a collection" do
  before do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    @posts = PostRepository.new.find_by_user_id(1)
  end

  it "has the right size" do
    @posts.size.must_equal 2
  end

  it "has a cache key" do
    @posts.cache_key.must_equal 'd630281e7b240892745b975d6b3ff9abe4fb3064/c7244914c7109201527c1b59930b64d242eca842'
  end

  describe "a single post from the collection" do
    subject { @posts.first }

    it "has the right body" do
      subject.body.must_equal "How is everybody today?"
    end

    it "generates a questionmark method" do
      subject.body?.must_equal true
    end

    it "renames foreign element names and converts integers" do
      subject.id.must_equal 1
      subject.user_id.must_equal 1
    end

    it "returns nil for elements not in the resource" do
      subject.parent_id.must_be_nil
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

describe 'requesting a single resource' do
  before do
    fake_http '/users/1/posts/2.xml', fixture('user_post')
    @post = PostRepository.new.find_by_user_id_and_post_id(1, 2)
  end

  subject { @post }

  it "has the right body" do
    subject.body.must_equal "When will world see Baby Cambridge?"
  end

  it "has a cache key" do
    subject.cache_key.must_equal 'd2c6c472195a1f74b8271c5e7ced007cf9b2821e/c9e3c5a555a38cc7f99c3cdada0e5ec02341c674'
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

  it "has a cache key" do
    @posts = @repository.find_by_user_id(1)
  end

  it "caches when response header includes Last-Modified" do
    @repository.find_by_user_id(1).size.must_equal(2)
    @posts = @repository.find_by_user_id(1).size.must_equal(2)
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

  it "should work the same for domain layer type models" do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    PostDomainRepository.new.find_by_user_id(1)
  end
end

describe "creating a new instance" do
  it "allows to create a new instance with an attribute hash" do
    p = Post.new :body => 'hi'
    p.body.must_equal 'hi'
  end
end

describe "being wrapped by a domain layer" do
  before do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    @posts = PostDomainRepository.new.find_by_user_id(1)
    @post = @posts.first
  end

  it "handles a collection" do
    @post.published?.must_equal true
    @post.user.first_name.must_equal 'John'
  end

  it "allows filtering by letting the instantiator return nil" do
    @posts.size.must_equal 1
  end
end

describe "passing a block instead of a class to collection" do
  it "returns the parsed document" do
    fake_http '/users/1/posts.xml', fixture('user_posts')
    repository = BlogPostRepository.new
    repository.all.first.id.must_equal 1
  end
end


