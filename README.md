# Relax

A [jsonapi.org](http://jsonapi.org) server implimentation in Elixir.

## Rationale

### Adoption

To drive Elixir adoption at my work place by making the simple use case of building Restful jsonapi.org servers painless and easy. After it is already in the door the more challenging problems will get tackled.

### Simplicity

Powerful, full featured frameworks like Pheonix provide tons of functionality and value, but simple APIs call for simple tools.

### Standard

JSON APIs are notoriously inconsistent. By adopting the [jsonapi.org](http://jsonapi.org) spec much bikeshedding can be avoided and APIs can be built to spec.

## Installation

hex etc

## Usage

Relax is composed of 4 distinct layers of functionaliy, each of which builds upon the last, yet allows flexiability to integrate with the tools you already in use.

1. The serialization layer - Combine a struct and a conn to generate JsonAPI.org format.
2. Rendering helpers - Handle calling the serializers and returning the proper response.
3. Deserialization helpers - Take a JsonAPI.org POST/PUT/PATCH request, deserialize it, and provide params.
4. Routing layer - Handle the specified JsonAPI.org url structures. eg: /v1/comments/1 vs /v1/comments/1,2,3

### Basic Serialization

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

You can use a seperate DSL to define the json representation. Each serializer the presentation data structure based on the model and connection.

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

### Response helpers

These helpers lets you quickly abstract calling serializers and sending responses.


```elixir
# Simple plug example
defmodule MyApp.API.V1.Posts do
  use Plug.Router
  use Relax.Responders

  serializer MyApp.Serializers.V1.Post

  plug :match
  plug :dispatch

  get "/posts" do
    okay(conn, %MyApp.Models.Post{id: 1, title: "Foo"})
  end
end
```

### Params helpers

This layer is all about creating and updating your resources. It includes a plug parser to handle the JsonAPI.org content type, and an interface for filtering and transforming the request to the map you need.

```elixir
# Simple plug example
defmodule MyApp.API.V1.Posts do
  use Plug.Router
  use Relax.Responders
  use Relax.Params

  serializer MyApp.Serializers.V1.Post

  plug Plug.Parsers, parsers: [Relax.PlugParser]
  plug :match
  plug :dispatch

  post "/posts" do
    filter_params(conn, {"posts", [:title, :body]}) do
      case MyApp.Models.Post.create(params) do
        {:ok,    post}   -> created(conn, post)
        {:error, errors} -> invalid(conn, errors)
      end
    end
  end
end
```

### Relax Routing

This is the final layer, and wraps those above. It provides a Router and a Resource.

A Router is a thin layer on top of the existing Plug.Router implementation. It provides version and resource macros to let you quickly define resources.

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

A Relax.Resource includes all our response and params helpers in a tidy api.

A Relax.Resource expects some or all of `find_all/1', `find_many/2`, `find_one/2`, `create/1`, `update/2`, and `delete/2` to be defined. Adding the `:only` or `:except` options to the use Relax.Resource will limit which matches are defined.

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

  def match(_), do: not_found(conn)
end

```

## Credits

The design of Plug, Phoenix, and Ecto all influenced this library.

Additionally, the serialization DSL is influenced heavily by ActiveModel::Serializers.

## License

TODO: release & license.
