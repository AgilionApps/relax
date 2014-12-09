# Relax

A [jsonapi.org](http://jsonapi.org) serializer and optional server implementation in Elixir.

Relax can be used as a standalone API with a router and resources, or integrated into Phoenix.

## Standalone Example

```elixir

defmodule MyApp do
  def start, do: Plug.Adapters.Cowboy.http MyApp.Router, []

  defmodule Router do
    use Relax.Router

    plug :match
    plug :dispatch

    version :v1 do
      resource :posts, MyApp.API.Posts
    end
  end

  defmodule API.Posts do
    use Relax.Resource, only: [:find_all, :find_many, :find_one]

    serializer MyApp.Serializer.Post

    plug :match
    plug :dispatch

    def find_all(conn), do: okay(conn, MyApp.Post.all)

    def find_many(conn, ids), do: okay(conn, MyApp.Post.find_by_ids(ids))

    def find_all(conn, id) do
      case MyApp.Post.find(id) do
        nil  -> not_found(conn)
        post -> okay(conn, post)
      end
    end
  end

  defmodule Serializer.Post do
    use Relax.Serializer

    serialize "posts" do
      attributes [:id, :title, :body]
      has_many :comments, serializer: Serializer.Comment
    end

    def comments(post), do: post.comments.all
  end

  defmodule Serializer.Comment do
    serialize "comments" do
      attributes [:id, :body, :troll_name]
      has_one :post, field: :post_id
    end
  end
end

```

## Pheoenix Example

TODO: Better Phoenix support, this is currently untested.

```elixir

defmodule MyApp do

  defmodule PostController do
    use Phoenix.Controller

    plug :action

    def index(conn, _params) do
      posts = MyApp.Post.all
              |> MyApp.Serializer.Post.as_json(conn, %{})
              |> JSON.encode!
      json conn, posts
    end

  end
end

```


## Installation

Currently pre-alpha software, use at your own risk via github.

```elixir
{:relax, github: 'AgilionApps/relax'}
```

## Usage

### Relax.Serializer

It should be possible to integrate Relax into any existing applications/frameworks just using the serialization layer.

Given any map data structure:

```elixir
defmodel MyApp.Models.Post do
  defstruct id: nil, title: "Foo", body: "Bar", posted_at: nil, comment_ids: []
end

defmodel MyApp.Models.Comment do
  defstruct id: nil, post_id: nil, body: "spam"
end
```

You can use a separate DSL to define the json representation. Each serializer returns a map based on the given model and connection.

```elixir
defmodule MyApp.Serializers.V1.Post do
  use Relax.Serializer

  serialize "posts" do
    attributes [:id, :title, :body, :is_published]
    has_many :comments, ids: true
  end

  def is_published(post, _conn) do
    post.posted_at != nil
  end

  def comments(post, _conn) do
    post.comment_ids
  end
end
```

You can then pass the model to the serializer to get the jsonapi.org formated data structure for conversion to JSON.

```elixir
# In a standard plug:
json = %MyApp.Models.Post{id: 1, title: "Foo"}
  |> MyApp.Serializers.V1.Post.as_json(conn)
  |> Poison.Encoder.encode([])
# Don't forget the jsonapi.org content type!
conn
  |> put_resp_header("content-type", "application/vnd.api+json")
  |> send_resp(200, json)
```

### Relax.Router

The Relax.Router is a thin layer on top of the existing Plug.Router implementation. It provides version and resource macros to let you quickly define resources.

You can still use `Plug.Route.forward/2` and `Plug.Route.match/2` as well as hook into the plug stack normally.

```elixir
defmodule MyApp.Router do
  use Relax.Router

  plug :match
  plug :dispatch

  forward "/app", to: MyApp.Static

  version :v1 do
    resource :posts, MyApp.API.V1.Posts do
      resource :comments, MyApp.API.V1.Posts.Comments
    end
    resource :comments, MyApp.API.V1.Comments
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "")
  end
end
```

### Relax.Resource

Relax.Resource wraps macros routing to proper actions, serializing and sending responses, and filtering params.

A Relax.Resource delegates the appropriate path matches to the actions `find_all/1', `find_many/2`, `find_one/2`, `create/1`, `update/2`, and `delete/2`. 

In your resource you can choose to only support a subset of these using `:only` or `:except`.

Once again, normal Plug.Route plug stack, functions, and matching work, however they will be defined after the pre-generated resource matches.

```elixir

defmodule API.V1.Posts do
  use Relax.Resource, only: [:find_all, :find_one, :find_many]

  plug :match
  plug :dispatch

  serializer Serializers.V1.Post

  def find_all(conn) do
    okay(conn, Post.all)
  end

  def find_one(conn, id) do
    case Post.find(id) do
      nil  -> not_found(conn)
      post -> okay(conn, post)
    end
  end

  def find_many(conn, list_of_ids) do
    okay(conn, Post.find(list_of_ids))
  end

  def create(conn) do
    filter_params(conn, {"posts", [:title, :body]}) do
      case MyApp.Models.Post.create(params) do
        {:ok,    post}   -> created(conn, post)
        {:error, errors} -> invalid(conn, errors)
      end
    end
  end

  post '/:id/publish' do
    #...
    okay(conn, post)
  end

  def match(_), do: not_found(conn)
end

```

## License

TODO: release & license. (Apache 2)
