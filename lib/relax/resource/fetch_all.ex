defmodule Relax.Resource.FetchAll do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to GET / and GET /?filter[foo]=bar.

  Typically brought into your resource via `use Relax.Resource`.

  FetchAll defines three callback behaviours, all of which have a default,
  overrideable implementation.

  In addition this module uses `Relax.Resource.Fetchable`, for shared model 
  lookup logic with Relax.Resource.FindAll.
  """

  @type fetchable :: module | Ecto.Query.t | list

  @doc """
  Lookup a collection to return.

  This often returns an Ecto.Query or and Ecto.Model module name that has not 
  yet been sent to the repo. Relax will execute the query after filtering and
  format the response appropriately.

      # Return all models
      def fetch_all(_conn), do: MyApp.Models.Post

      # Return models limited to the current_user
      def fetch_all(conn), do: Ecto.assoc(conn.assigns[:current_user], :posts)

  It may also return a list of structs/models:

      def fetch_all(_conn), do: [%Post{title: "foo"}, %Post{title: "bar"}]

  A conn may also be returned:

      def fetch_all(conn), do: halt send_resp(conn, 401, "no posts for you")

  By default it returns the value of `fetchable/1` directly:

      def fetch_all(conn), do: fetchable(conn)

  """
  defcallback fetch_all(Plug.Conn.t) :: Plug.Conn.t | fetchable

  @doc """
  This callback can be used to completely override the fetch_all behaviour.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback fetch_all_resources(Plug.Conn.t) :: Plug.Conn.t

  @doc """
  Defines allowed filters for your resource.

  By default filters are ignored unless defined. Filters recieve the filter
  keyword, the query or collection returned from `fetch_all/1` and the filter
  value.

  Examples:

      # Ecto
      def filter("search", query, value) do
        Ecto.Query.where(queryable, [p], ilike(a.body, ^"%#{value}%"))
      end

      # Lists
      def filter("popular", posts, value) do
        Enum.filter(posts, fn(p) -> p.likes > 10 end)
      end

  """
  defcallback filter(atom, fetchable, String.t) :: fetchable

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      use Relax.Resource.Fetchable
      @behaviour Relax.Resource.FetchAll

      def do_resource(conn, "GET", []) do
        fetch_all_resources(conn)
      end

      def fetch_all_resources(conn) do
        conn
        |> fetch_all
        |> Relax.Resource.FetchAll.filter(conn, __MODULE__)
        |> Relax.Resource.FetchAll.execute_query(__MODULE__)
        |> Relax.Resource.FetchAll.respond(conn, __MODULE__)
      end

      def filter(_, list, _), do: list

      def fetch_all(conn), do: fetchable(conn)

      defoverridable [fetch_all_resources: 1, filter: 3, fetch_all: 1]
    end
  end

  @doc false
  def filter(results, conn, resource) do
    case conn.query_params["filter"] do
      nil -> results
      %{} = filters ->
        filters
        |> Dict.keys
        |> Enum.reduce results, fn(k, acc) ->
          resource.filter(k, acc, filters[k])
        end
    end
  end

  @doc false
  def execute_query(results, resource) do
    module = resource.model
    case results do
      %Ecto.Query{} = q -> resource.repo.all(q)
      ^module = q       -> resource.repo.all(q)
      other             -> other
    end
  end

  @doc false
  def respond(%Plug.Conn{} = c, _oldconn, _resource), do: c
  def respond(models, conn, resource) do
    Relax.Responders.send_json(conn, 200, models, resource)
  end
end
