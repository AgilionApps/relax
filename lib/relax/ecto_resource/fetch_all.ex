defmodule Relax.EctoResource.FetchAll do
  use Behaviour

  @type fetchable :: module | Ecto.Query.t | list

  defcallback fetch_all(Plug.Conn.t) :: Plug.Conn.t | fetchable
  defcallback fetch_all_resources(Plug.Conn.t) :: Plug.Conn.t
  defcallback filter(atom, fetchable, String.t) :: fetchable

  @doc false
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Relax.EctoResource.FetchAll

      def do_resource(conn, "GET", []) do
        fetch_all_resources(conn)
      end

      def fetch_all_resources(conn) do
        conn
        |> fetch_all
        |> Relax.EctoResource.FetchAll.filter(conn, unquote(opts)[:filters], __MODULE__)
        |> Relax.EctoResource.FetchAll.execute_query(__MODULE__)
        |> Relax.EctoResource.FetchAll.respond(conn, __MODULE__)
      end

      def filter(_, list, _), do: list

      defoverridable [fetch_all_resources: 1, filter: 3]
    end
  end

  @doc false
  def filter(results, conn, nil, r), do: filter(results, conn, [], r)
  def filter(results, conn, allowed, resource) do
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
    conn
    |> Relax.Responders.send_json(200, models, resource.serializer)
    |> Plug.Conn.halt
  end
end
