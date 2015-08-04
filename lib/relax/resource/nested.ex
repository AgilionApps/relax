defmodule Relax.Resource.Nested do
  @behaviour Plug

  @moduledoc """
  Converts nested resources from Relax.Routers to JSON API style filters.
  """

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    case {conn.private[:relax_parent_name], conn.private[:relax_parent_id]} do
      {nil, _}   -> conn
      {_, nil}   -> conn
      {name, id} -> expose_nested(conn, name, id)
    end
  end

  defp expose_nested(conn, name, id) do
    new = %{"filter" => Map.put(%{}, name, id)}
    merged = Dict.merge conn.query_params, new, fn(_k, v1, v2) ->
      Dict.merge(v1, v2)
    end
    Map.put(conn, :query_params, merged)
  end
end
