defmodule Relax.Resource.Update do
  use Behaviour

  @doc "Updates resource, sets conn status and body"
  defcallback update(conn :: Plug.Conn.t, id :: binary) :: Plug.Conn.t

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Resource.Update

      def update(conn, _id), do: conn
      defoverridable [update: 2]

      patch "/:id", do: update(var!(conn), var!(id))
      put   "/:id", do: update(var!(conn), var!(id))
    end
  end
end
