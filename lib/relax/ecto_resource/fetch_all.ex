defmodule Relax.EctoResource.FetchAll do
  defmacro __using__(opts) do
    quote location: :keep do
      def do_resource(conn, "GET", []) do
        fetch_all_resources(conn)
      end

      def fetch_all_resources(conn) do
        fetch_all(conn)
        |> do_filter(conn)
        |> do_execute
        |> respond_fetch_all(conn)
      end

      def filter(_, any, _), do: any

      defoverridable [fetch_all_resources: 1, filter: 3]

      def do_filter(results, conn) do
        case conn.query_params["filter"] do
          nil -> results
          %{} = filters ->
            allowerd_filters = unquote(opts)[:filters] || []
            filters
            |> Dict.keys
            |> Enum.map(&String.to_existing_atom/1)
            |> Enum.filter(&(&1 in allowerd_filters))
          |> Enum.reduce results, fn(k, acc) ->
            filter(k, acc, filters[Atom.to_string(k)])
          end
        end
      end

      def do_execute(results) do
        module = model()
        case results do
          %Ecto.Query{} = q -> repo.all(q)
          ^module = q       -> repo.all(q)
          other             -> other
        end
      end

      def respond_fetch_all(%Plug.Conn{} = c, _oldconn), do: c
      def respond_fetch_all(other, conn), do: halt okay(conn, other)
    end
  end
end
