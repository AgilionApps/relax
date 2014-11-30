defmodule Relax.Formatter.JsonApiOrg.LinkedResources do
  alias Relax.Formatter.JsonApiOrg.Format
  alias Relax.Serializer.Relationships

  @moduledoc """
  Recursively find and add all needed linked resources.
  """

  defmodule Resource do
    defstruct key: nil, id: nil, resource: %{}, serializer: nil
  end

  def add(results, context) do
    case all(context.model, context.serializer, context.conn) do
      linked when map_size(linked) > 0 -> Map.put(results, "linked", linked)
      _                                -> results
    end
  end

  # Find all relations, convert to nested data structure
  defp all(%{} = model, serializer, conn), do: all([model], serializer, conn)
  defp all(models, serializer, conn) do
    find_all(models, serializer, conn)
    |> Enum.uniq(fn(%Resource{key: key, id: id}) -> {key, id} end)
    |> group_and_format(conn)
  end

  # Find first level of resources.
  defp find_all(models, serializer, conn) do
    relations_for(models, serializer, conn)
    |> do_find_all(conn, [])
  end

  # Find each recursive layer of resources
  # TODO: recursive relationships will cause loop, can we address that?
  defp do_find_all([], _conn, results), do: results
  defp do_find_all(resources, conn, results) do
    resources
      |> Enum.flat_map &relations_for(&1.resource, &1.serializer, conn)
      |> do_find_all(conn, results ++ resources)
  end

  # Extracts the relations from one model, returning an array of Resources.
  defp relations_for(%{} = model, serializer, conn) do
    Relationships.included(serializer, model, conn)
    |> Enum.map fn({key, child_serializer, child}) ->
      %Resource{
        key:        key,
        serializer: child_serializer,
        resource:   child,
        id:         Map.get(child, :id)
      }
    end
  end

  defp relations_for(models, serializer, conn) do
    Enum.flat_map models, &relations_for(&1, serializer, conn)
  end

  defp group_and_format(resources, conn) do
    Enum.reduce resources, %{}, fn(r, results) ->
      formatted = Format.format_resource(r.serializer, r.resource, conn)
      Map.update(results, r.key, [formatted], &[formatted | &1])
    end
  end

end
