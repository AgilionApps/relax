defmodule Relax.Resource.Delete do
  use Behaviour

  @doc "Deletes resource, sets conn status and body"
  defcallback delete(conn :: Plug.Conn.t, id :: binary) :: Plug.Conn.t

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Resource.Delete

      def delete(conn, _id), do: conn
      defoverridable [delete: 2]

      delete "/:id", do: delete(var!(conn), var!(id))
    end
  end
end
