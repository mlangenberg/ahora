require 'nibbler'
require 'faraday'
require 'nokogiri'
require 'date'
require 'active_support/core_ext/string'

module Ahora
  module Resource
    USERNAME = 'user'
    PASSWORD = 'pass'
    HOST      = 'http://test.net/'

    def get(mapper, url, params = {})
      response = connection.get do |req|
        req.url url, params
      end
      doc = Nokogiri::XML.parse(response.body, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
      mapper.parse(doc).object
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

  class Representation < Nibbler
    INTEGER_PARSER = lambda { |node| Integer(node.content) if node.content.present? }
    DATE_PARSER = lambda { |node| Date.parse(node.content) if node.content.present? }

    module Definition
      def attribute(*names)
        names = names.flatten
        parser = names.pop if names.last.is_a?(Proc)
        names.each do |name|
          selector = name
          if name.is_a? Hash
            selector, name = name.first
          end
          element selector.to_s.camelcase(:lower) => name.to_s, :with => parser
        end
      end

      # Public: define Java style object id mapping
      #
      # *names - Array of String or Symbol ruby style names
      #
      # Examples
      #
      # objectid :id, parent_id
      # # is equivalent to
      # element 'objectId'
      # element 'parentObjectId'
      def objectid(*names)
        attribute names.map { |name| { name.to_s.gsub('id', 'object_id') => name } }, INTEGER_PARSER
      end

      def string(*names)
        attribute(names)
      end

      def integer(*names)
        attribute(names, INTEGER_PARSER)
      end

      def date(*names)
        attribute(names, DATE_PARSER)
      end
    end

    extend Definition
  end
end


## specs

if __FILE__== $0
  require 'fakeweb'
  require 'minitest/autorun'
  XML = DATA.read

  FakeWeb.allow_net_connect = false

  def fake_http(uri, body)
    FakeWeb.register_uri :get, 'http://user:pass@test.net' + uri, :body => body
  end

  class Post
    extend Ahora::Resource

    class PostMapper < Ahora::Representation
      objectid :id, :user_id, :parent_id
      date  :created_at
      element :body
      element 'user', :with => Class.new(Ahora::Representation) do
        string :first_name, :last_name
      end
      elements 'replies/userPost' => :replies, :with => PostMapper
    end

    class PostsMapper < Nibbler
      elements '/userPosts/userPost' => :object, :with => PostMapper
    end

    # TODO test with limit/offset params
    def self.find_by_user_id(id)
      get PostsMapper,"/users/#{id}/posts.xml"
    end
  end


  describe "requesting a collection" do
    before do
      fake_http '/users/1/posts.xml', XML
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

end

__END__
<?xml version="1.0"?>
<userPosts type="array">
  <userPost>
    <objectId>1</objectId>
    <userObjectId>1</userObjectId>
    <user>
      <firstName>John</firstName>
      <lastName>Doe</lastName>
    </user>
    <body>How is everybody today?</body>
    <createdAt>2011-10-26T17:01:52+02:00</createdAt>

    <replies type="array">
      <userPost>
        <objectId>2</objectId>
        <parentObjectId>1</parentObjectId>
        <userObjectId>2</userObjectId>
        <user>
          <firstName>Mike</firstName>
          <lastName>Smith</lastName>
        </user>
        <body>I am fine, thanks for asking.</body>
        <createdAt>2011-10-27T9:00:00+02:00</createdAt>
      </userPost>
      <userPost>
        <objectId>3</objectId>
        <parentObjectId>1</parentObjectId>
        <userObjectId>1</userObjectId>
        <user>
          <firstName>John</firstName>
          <lastName>Doe</lastName>
        </user>
        <body>You are more than welcome.</body>
        <createdAt>2011-10-27T9:00:00+02:00</createdAt>
      </userPost>
    </replies>
  </userPost>
</userPosts>