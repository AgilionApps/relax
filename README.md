# Relax

**A Plug based toolset for building simple [jsonapi.org](http://jsonapi.org)
spec APIS.**

Relax is still in an early state of development (pre 1.0), so please check the
changelog before updating.

Relax APIs are composed of a Router and Resources for handling requests, and
complimented by [JaSerializer](http://github.com/AgilionApps/ja_serializer) for
formatting responses.

## Example

This example exposes the following endpoints:

* GET    /v1/posts/
* GET    /v1/posts/?page=1&size=100
* GET    /v1/posts/?filter[title]=elixir
* GET    /v1/posts/:id
* POST   /v1/posts
* PUT    /v1/posts/:id
* DELETE /v1/posts/:id

```elixir
defmodule MyApp do
  defmodule Router do
    use Relax.Router

    plug :router
    plug :not_found

    version :v1 do
      resource :posts, MyApp.API.Posts
    end
  end

  defmodule API.Posts do
    use Relax.Resource

    def serializer, do: MyApp.Serializer.Post
    def error_serializer, do: JaSerializer.EctoErrorSerializer
    def model, do: MyApp.Models.Post

    plug :resource
    plug :not_found

    def fetchable(conn) do
      Ecto.Model.assoc(conn.assigns[:current_user], :posts)
    end

    def filter("title", queryable, value) do
      Ecto.Query.where(queryable, [p], ilike(a.title, ^"%#{value}%"))
    end

    def create(_conn, attributes) do
      MyApp.Models.Post.changeset(:create, attributes)
    end

    def update(_conn, post, attributes) do
      MyApp.Models.Post.changeset(:create, post, attributes)
    end

    def delete(_conn, post) do
      MyApp.Repo.delete!(post)
    end

    def permitted_attributes(_model, _conn), do: [:title, :body]
    def permitted_relations(_model, _conn), do: []
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
{:relax, "~> 0.2.2"}
```

## Usage/Documentation

See [http://hexdocs.pm/relax](http://hexdocs.pm/relax) for detailed usage and
documentation.

## jsonapi.org Spec Compliance

Please see [JaSerializer](http://github.com/AgilionApps/ja_serializer) for
data serialization compliance.

- [x] Content Negotiation
  - [x] [Send content type](http://jsonapi.org/format/#content-negotiation)
  - [x] [Reject media type](http://jsonapi.org/format/#content-negotiation)
- [x] Document Structure - see [JaSerializer](http://github.com/AgilionApps/ja_serializer)
- [ ] Fetching Data
  - [x] [Fetching Resources](http://jsonapi.org/format/#fetching-resources)
  - [x] [Filtering](http://jsonapi.org/format/#fetching-filtering)
  - [ ] [Fetching Relationships](http://jsonapi.org/format/#fetching-relationships)
  - [ ] [Fetching Includes](http://jsonapi.org/format/#fetching-includes) (includes query param not supported)
  - [ ] [Sparse Fieldsets](http://jsonapi.org/format/#fetching-sparse-fieldsets)
  - [x] [Sorting](http://jsonapi.org/format/#fetching-sorting)
  - [ ] [Pagination](http://jsonapi.org/format/#fetching-pagination)
- [ ] CRUD
  - [x] [Creating Resources](http://jsonapi.org/format/#crud-creating)
  - [x] [Updating Resources](http://jsonapi.org/format/#crud-updating)
  - [x] [Deleting Resources](http://jsonapi.org/format/#crud-deleting)
  - [ ] [Updating Relationships](http://jsonapi.org/format/#crud-updating-relationships)
- [ ] [Errors](http://jsonapi.org/format/#errors)
- [ ] Query Params - [Not currently enforced](http://jsonapi.org/format/#query-parameters)

## License

Relax source code is released under Apache 2 License. Check LICENSE file for more information.
