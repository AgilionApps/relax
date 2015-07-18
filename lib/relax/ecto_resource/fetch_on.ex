defmodule Relax.EctoResource.FetchOne do
  defmacro __using__(_opts) do
    quote do
      def do_resource(conn, "GET", [id]) do
        fetch_one_resource(conn, id)
      end

      def fetch_one_resource(conn, id) do
        module = model()
        case fetch_one(conn, id) do
          %Ecto.Query{} = q -> respond_fetch_one(conn, repo.get(q, id))
          ^module       = q -> respond_fetch_one(conn, repo.get(q, id))
          %Plug.Conn{}  = c -> c
          other             -> respond_fetch_one(conn, other)
        end
      end

      defoverridable [fetch_one_resource: 2]

      defp respond_fetch_one(conn, nil), do: halt not_found(conn)
      defp respond_fetch_one(conn, model), do: halt okay(conn, model)
    end
  end
end
