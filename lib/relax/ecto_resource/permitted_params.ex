defmodule Relax.EctoResource.PermittedParams do
  use Behaviour

  defcallback permitted_attributes(atom, Plug.Conn.t) :: [atom]
  defcallback permitted_relations(atom, Plug.Conn.t) :: [atom]

  @doc """
  Filters the JSONAPI attributes and relationships based on keyword list
  """
  def filter(%Plug.Conn{params: p}, opts) do
    relationships = Enum.reduce opts[:relations], %{}, fn(r, acc) ->
      key = Atom.to_string(r)
      val = p["data"]["relationships"][key]["data"]["id"]
      Dict.put(acc, key <> "_id", val)
    end

    p["data"]["attributes"]
    |> Dict.take(Enum.map(opts[:attributes], &Atom.to_string/1))
    |> Dict.merge(relationships)
  end
end
