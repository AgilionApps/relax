defmodule Relax.Resource.FindAll do
  use Behaviour

  @doc "Finds all objects for resource, sets conn status and body"
  defcallback find_all(conn :: Plug.Conn.t) :: Plug.Conn.t

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Resource.FindAll
      def find_all(conn), do: conn
      defoverridable [find_all: 1]

      get "/", do: find_all(var!(conn))
    end
  end
end
