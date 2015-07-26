defmodule Relax.Resource.Fetchable do
  use Behaviour

  @type fetchable :: module | Ecto.Query.t | list
  defcallback fetchable(Plug.Conn.t) :: fetchable

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.Resource.Fetchable

      def fetchable(_conn), do: __MODULE__.model

      defoverridable [fetchable: 1]
    end
  end
end
