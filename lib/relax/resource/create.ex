defmodule Relax.Resource.Create do
  use Behaviour

  @doc "Creates resource, sets conn status and body"
  defcallback create(conn :: Plug.Conn.t) :: Plug.Conn.t

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Resource.Create
      def create(conn), do: conn
      defoverridable [create: 1]

      post "/", do: create(var!(conn))
    end
  end
end
