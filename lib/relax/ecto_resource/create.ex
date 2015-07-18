defmodule Relax.EctoResource.Create do
  defmacro __using__(opts) do
    quote location: :keep do
      def do_resource(conn, "POST", []) do
        create_resource(conn)
      end

      def create_resource(conn) do
        attributes = Relax.EctoResource.filter_attributes(conn, unquote(opts))
        respond_create(conn, create(conn, attributes))
      end

      defoverridable [create_resource: 1]

      def respond_create(conn, %Ecto.Changeset{} = change) do
        if change.valid? do
          halt created(conn, repo.insert!(change))
        else
          halt invalid(conn, change.errors)
        end
      end

      def respond_create(_conn, %Plug.Conn{} = conn) do
        conn
      end

      def respond_create(conn, {:error, errors}) do
        halt invalid(conn, errors)
      end

      def respond_create(conn, {:ok, model}) do
        halt created(conn, model)
      end

      def respond_create(conn, %{} = model) do
        halt created(conn, model)
      end
    end
  end
end
