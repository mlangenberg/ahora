Ahora
=====

An alternative to ActiveResource for consuming Java-ish XML HTTP Resources easily. *Ahora* glues together two amazing Ruby libraries: [Faraday](https://github.com/technoweenie/faraday) and [Nibbler](https://github.com/mislav/nibbler).

If your project meets any of the following requirements, you might be interested.

 * You want to consume an external XML resource.
 * You want to map camelCase names to underscore_case.
 * You want to parse Date, Time and boolean values automatically.
 * You want to be a good citizen on the web and support caching (e.g. If-Modified-Since).
 * You want to use fragment caching on the front-end. So it should generate a cache-key.
 * You might have a recently cached fragment, so XML collections should be lazy loaded.

This is a big list, you might not need all these requirements. At least the code can act as an example on how to approach one of these problems.

Example
---

Let's say you want to display to following XML on a page in a Rails project

~~~ xml
<?xml version="1.0"?>
<userPosts type="array">
  <userPost>
	<hidden>false</hidden>
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
  <userPost>
    <hidden>true</hidden>
  </userPost>
</userPosts>
~~~

You start by defining a class with methods to retrieve the resource and another class to act as a mapper.

~~~ ruby
class Post < Ahora::Representation
  objectid :id, :user_id, :parent_id
  date  :created_at
  element :body
  element 'user', :with => Ahora::Representation do
    string :first_name, :last_name
  end
  boolean :hidden
  elements 'replies/userPost' => :replies, :with => Post
end

class PostResource
  include Ahora::Resource

  def all
    collection Post, get("/api/posts.xml")
  end

  private
  def host
    'http://test.net'
  end

  def extend_middleware(builder)
    builder.use Ahora::Middleware::LastModifiedCaching, Rails.cache
  end
end
~~~

Now you can define a controller as usual.

~~~ ruby
class PostsController < ApplicationController::Base
  def index
    @posts = PostResource.new.all
  end
end
~~~

And a view template

~~~ html
  <% cache @posts, 'index' %>
    <%= render(:partial => @posts) %>
  <% end >
~~~

And that's all there is. The XML response will be cached, so it saves a bandwith. The XML response will only be parsed if there is no existing HTML fragment cache. All cache will be invalidated when the request to posts.xml returns a new body instead of a 304 Not Modified.