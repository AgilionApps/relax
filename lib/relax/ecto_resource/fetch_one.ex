defmodule Relax.EctoResource.FetchOne do
  use Behaviour

  @type fetchable :: module | Ecto.Query.t | map
  @type id :: integer | String.t

  defcallback fetch_one(Plug.Conn.t, id) :: Plug.Conn.t | fetchable
  defcallback fetch_one_resource(Plug.Conn.t) :: Plug.Conn.t
  defcallback filter(atom, fetchable, String.t) :: fetchable

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Relax.EctoResource.Create

      def do_resource(conn, "GET", [id]) do
        fetch_one_resource(conn, id)
      end

      def fetch_one_resource(conn, id) do
        conn
        |> fetch_one(conn)
        |> Relax.EctoResource.FetchOne.execute_query(id, __MODULE__)
        |> Relax.EctoResource.FetchOne.respond(conn, __MODULE__)
      end

      defoverridable [fetch_one_resource: 2]
    end
  end

  @doc false
  def execute_query(query, id, resource) do
    module = resource.model
    case query do
      %Ecto.Query{} = q -> resource.repo.get(q, id)
      ^module       = q -> resource.repo.get(q, id)
      other             -> other
    end
  end

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(nil, conn, _resource) do
      conn
      |> Plug.Conn.send_resp(404, "")
      |> Plug.Conn.halt
  end
  def respond(model, conn, resource) do
    conn
    |> Relax.Responders.send_json(200, model, resource.serializer)
    |> Plug.Conn.halt
  end
end
