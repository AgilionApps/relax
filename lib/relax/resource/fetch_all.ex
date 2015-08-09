defmodule Relax.Resource.FetchAll do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to GET / and GET /?filter[foo]=bar.

  Typically brought into your resource via `use Relax.Resource`.

  FetchAll defines three callback behaviours, all of which have a default,
  overrideable implementation.

  In addition this module uses `Relax.Resource.Fetchable`, for shared model 
  lookup logic with Relax.Resource.FetchOne.
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
  This callback can be used to completely override the fetch_all action.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback fetch_all_resources(Plug.Conn.t) :: Plug.Conn.t

  @doc ~S"""
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
  defcallback filter(String.t, fetchable, String.t) :: fetchable


  @doc """
  Defines allowed sort fields for your resource.

  By default sort params are ignored unless defined. Sorts recieve the field,
  the query or collection returned from `fetch_all/1` and the atom :asc or :desc.

  Examples:

      # Ecto (asc)
      # /resource/?sort=likes,rating
      def sort("likes", query, :asc) do
        Ecto.Query.order_by(query, [t], asc: :likes)
      end
      def sort("rating", query, :asc) do
        Ecto.Query.order_by(query, [t], asc: :rating)
      end

      # Lists (desc)
      # /resource/?sort=-name
      def sort("name", list, :desc) do
        Enum.sort_by(list, &(&1.name)) |> Enum.reverse
      end

  """
  defcallback sort(String.t, fetchable, atom) :: fetchable

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      use Relax.Resource.Fetchable
      @behaviour Relax.Resource.FetchAll
      @before_compile Relax.Resource.FetchAll

      def do_resource(conn, "GET", []) do
        fetch_all_resources(conn)
      end

      def fetch_all_resources(conn) do
        conn
        |> fetch_all
        |> Relax.Resource.FetchAll.filter(conn, __MODULE__)
        |> Relax.Resource.FetchAll.sort(conn, __MODULE__)
        |> Relax.Resource.FetchAll.execute_query(__MODULE__)
        |> Relax.Resource.FetchAll.respond(conn, __MODULE__)
      end

      def fetch_all(conn), do: fetchable(conn)

      defoverridable [fetch_all_resources: 1, fetch_all: 1]
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def filter(_, results, _), do: results
      def sort(_, results, _), do: results
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

  @sort_regex ~r/(-?)(\S*)/
  @doc false
  def sort(results, conn, resource) do
    case conn.query_params["sort"] do
      nil -> results
      fields ->
        fields
        |> String.split(",")
        |> Enum.reduce results, fn(field, acc) ->
          case Regex.run(@sort_regex, field) do
            [_, "", field] -> resource.sort(field, results, :asc)
            [_, "-", field] -> resource.sort(field, results, :desc)
          end
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
