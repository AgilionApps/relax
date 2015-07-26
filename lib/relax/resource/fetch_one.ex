defmodule Relax.Resource.FetchOne do
  use Behaviour

  @type id :: integer | String.t

  defcallback fetch_one(Plug.Conn.t, id) :: Plug.Conn.t | map
  defcallback fetch_one_resource(Plug.Conn.t, id) :: Plug.Conn.t

  defmacro __using__(_opts) do
    quote location: :keep do
      use Relax.Resource.Fetchable
      @behaviour Relax.Resource.FetchOne

      def do_resource(conn, "GET", [id]) do
        fetch_one_resource(conn, id)
      end

      def fetch_one_resource(conn, id) do
        conn
        |> fetch_one(id)
        |> Relax.Resource.FetchOne.respond(conn, __MODULE__)
      end

      def fetch_one(conn, id) do
        conn
        |> fetchable
        |> Relax.Resource.FetchOne.execute_query(id, __MODULE__)
      end

      defoverridable [fetch_one_resource: 2, fetch_one: 2]
    end
  end

  @doc false
  def execute_query(query, id, resource) do
    module = resource.model
    case query do
      nil               -> nil
      %Ecto.Query{} = q -> resource.repo.get(q, id)
      ^module       = q -> resource.repo.get(q, id)
      other             -> other
    end
  end

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(nil, conn, _resource) do
    Relax.Responders.not_found(conn)
  end
  def respond(model, conn, resource) do
    Relax.Responders.send_json(conn, 200, model, resource)
  end
end
