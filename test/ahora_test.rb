
require 'fakeweb'
require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/ahora'

FakeWeb.allow_net_connect = false


def fake_http(uri, fixture)
  fixture = File.join(File.dirname('__FILE__'), 'test', 'fixtures', "#{fixture}.xml")
  FakeWeb.register_uri :get, 'http://user:pass@test.net' + uri, :body => File.open(fixture)
end

class Post < Ahora::Representation
  extend Ahora::Resource

  objectid :id, :user_id, :parent_id
  date  :created_at
  element :body
  element 'user', :with => Ahora::Representation do
    string :first_name, :last_name
  end
  elements 'replies/userPost' => :replies, :with => Post

  def self.find_by_user_id(id)
    collection get "/users/#{id}/posts.xml"
  end
end


describe "requesting a collection" do
  before do
    fake_http '/users/1/posts.xml', 'user_posts'
    @posts = Post.find_by_user_id(1)
  end

  it "has the right size" do
    @posts.size.must_equal 1
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