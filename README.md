# Relax

An API routing library aimed at building [jsonapi.org](http://jsonapi.org)
spec servers on top of plug.

*WARNING: As of Relax 0.1.0 serialization is handled by a seperate library:
[JaSerializer](http://github.com/AgilionApps/ja_serializer).*

Relax APIs are composed a Router and Resources. Both Routers and Resources
are simple DSLs on top of standard Plugs.


## Standalone Example

Simple Plug based DSLs for routing/dispatching API requests.

```elixir

defmodule MyApp do
  # Our Router is just a plug router and we can start it as such.
  def start, do: Plug.Adapters.Cowboy.http MyApp.Router, []

  # Our router is our main entry point for all requests.
  # Relax.Router is just a DSL on top of Plug.Router, so the standard plug
  # stack still works and is used.
  defmodule Router do
    use Relax.Router

    plug :match
    plug :dispatch

    version :v1 do

      # Dispatch all /v1/posts/* requests to MyApp.API.Posts plug.
      resource :posts, MyApp.API.Posts
    end
  end

  # Our "Resource" similar to a controller, is just different DSL on a Plug.Router.
  # By including Relax.Resource we define matches for:
  # * GET /:id
  # * GET /
  # * POST /
  # * PUT(or PATCH) /:id
  # * DELETE /:id.
  # Each match is then dispatched to the proper callback.

  defmodule API.Posts do
    # Don't match put or delete (:update or :delete)
    use Relax.Resource, only: [:find_all, :find_one, :create]

    # Every resource is expected to define a serializer. 
    # This will be used by each request. And is expected to be a JaSerializer
    # serializer
    serializer MyApp.Serializer.Post

    plug :match
    plug :dispatch

    # Call back for GET / - returns 200 with all posts serialized
    def find_all(conn), do: okay(conn, MyApp.Post.all)

    # Call back for GET /:id1 returns 200 with posts serialized or 404
    def find_one(conn, id) do
      case MyApp.Post.find(id) do
        nil  -> not_found(conn)
        post -> okay(conn, post)
      end
    end
  end

  defmodule Serializer.Post do
    use JaSerializer

    serialize "posts" do
      attributes [:id, :title, :body]
    end
  end
end

```


## Installation

Relax is Alpha software and APIs are still stabalizing, use at your own risk.

```elixir
{:relax, "~> 0.1.0"}
```

## Usage
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

Relax.Resource wraps macros routing to proper actions as well as serializing and sending responses.

A Relax.Resource delegates the appropriate path matches to the actions `find_all/1', `find_one/2`, `create/1`, `update/2`, and `delete/2`.

In your resource you can choose to only support a subset of these using `:only` or `:except`.

Once again, normal Plug.Route plug stack, functions, and matching work, however they will be defined after the pre-generated resource matches.

```elixir

defmodule API.V1.Posts do
  use Relax.Resource, only: [:find_all, :find_one, :create]

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

  def create(conn) do
    case MyApp.Models.Post.create(attributes(conn)) do
      {:ok,    post}   -> created(conn, post)
      {:error, errors} -> invalid(conn, errors)
    end
  end

  post '/:id/publish' do
    #...
    okay(conn, post)
  end

  def match(_), do: not_found(conn)

  defp attributes(%{params: params} = conn) do
    params["data"]["attributes"]
    |> Dict.take(["title", "body"])
  end
end

```

## License

Relax source code is released under Apache 2 License. Check LICENSE file for more information.
