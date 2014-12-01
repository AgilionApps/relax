defmodule Relax.Serializer.Relationships do
  def nested(serializer, model, conn) do
    Enum.reduce serializer.__relations, %{}, fn({type, name, opts}, results) ->
      nested = nested_relation(serializer, model, conn, {type, name, opts})
      Map.put(results, name, nested)
    end
  end

  defp nested_relation(serializer, model, conn, {type, name, opts}) do
    if opts[:link] do
      %{href: Relax.Serializer.Location.generate(model, serializer, conn, opts[:link])}
    else
      nested_ids(serializer, model, conn, {type, name, opts})
    end
  end

  # Returns nested ids, assuming either ids, or models if opts serializer
  defp nested_ids(serializer, model, conn, {_type, name, opts}) do
    models_or_ids = apply(serializer, name, [model, conn])
    if opts[:serializer] do
      models_or_ids = Enum.map models_or_ids, &(Map.get(&1, :id))
    end
    models_or_ids
  end

  @doc """
  Gets all the resources included directly by the given serializer/model.

  Returns list of tuples {relation_key, serializer, model}
  """
  def included(serializer, parent, conn) do
    serializer.__relations
    |> Enum.filter(fn({_type, _name, opts}) -> opts[:serializer] end)
    |> Enum.flat_map &find_included(serializer, parent, conn, &1)
  end

  defp find_included(parent_serializer, parent, conn, {_, name, opts}) do
    fun = opts[:fn] || name
    apply(parent_serializer, fun, [parent, conn])
    |> Enum.map &({name, opts[:serializer], &1})
  end
end
