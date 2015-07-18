defmodule Relax.EctoResource.Update do
  defmacro __using__(opts) do
    quote do
      def do_resource(conn, "PUT", [id]) do
        update_resource(conn, id)
      end

      def update_resource(conn, id) do
        model = case fetch_one(conn, id) do
          %Ecto.Query{} = q -> repo.get(q, id)
          model -> model
        end
        case model do
          nil   -> halt not_found(conn)
          model ->
            attributes = Relax.EctoResource.filter_attributes(conn, unquote(opts))
            respond_update(conn, update(conn, model, attributes))
        end
      end

      defoverridable [update_resource: 2]

      def respond_update(conn, %Ecto.Changeset{} = change) do
        if change.valid? do
          halt okay(conn, repo.update!(change))
        else
          halt invalid(conn, change.errors)
        end
      end

      def respond_update(_, %Plug.Conn{} = conn) do
        conn
      end

      def respond_update(conn, {:error, errors}) do
        halt invalid(conn, errors)
      end

      def respond_update(conn, {:ok, model}) do
        halt okay(conn, model)
      end

      def respond_update(conn, nil) do
        halt not_found(conn)
      end

      def respond_update(conn, %{} = model) do
        halt okay(conn, model)
      end
    end
  end
end
