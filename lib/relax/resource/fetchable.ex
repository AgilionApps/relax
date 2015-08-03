defmodule Relax.Resource.Fetchable do
  use Behaviour

  @type fetchable :: module | Ecto.Query.t | list

  @moduledoc """
  A behaviour for fetching models.

  Typically brought into your resource via `use Relax.Resource`.
  """

  @doc"""
  Define the base collection of models to be fetched.

  Return a query or collection of models to be used by `fetch_all` and
  `fetch_one`.

      # Return all models to be queried.
      def fetchable(_conn), do: MyApp.Models.Post

      # Return query limited to the current_user to be queried.
      def fetchable(conn), do: Ecto.assoc(conn.assigns[:current_user], :posts)

  It may also return a list of structs/models:

      def fetchable(_conn), do: [%Post{title: "foo"}, %Post{title: "bar"}]
  """
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
