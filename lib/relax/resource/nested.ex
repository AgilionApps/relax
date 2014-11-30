defmodule Relax.Resource.Nested do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    case {conn.private[:relax_parent_name], conn.private[:relax_parent_id]} do
      {nil, _}   -> conn
      {_, nil}   -> conn
      {name, id} -> Map.update(conn, :params, %{}, &(Map.put(&1, name, id)))
    end
  end
end
