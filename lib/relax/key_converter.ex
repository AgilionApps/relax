defmodule Relax.ConvertKeys do
  @moduledoc """
  Recursively converts keys in nested data structures
  """
  def camelize(data),   do: convert_keys(data, :camelize_key)
  def underscore(data), do: convert_keys(data, :underscore_key)

  # Don't format keys on structs.
  defp convert_keys(%{__struct__: _} = map, fun) do
    map
  end

  defp convert_keys(map, fun) when is_map(map) do
    Enum.reduce map, %{}, fn({k, v}, a) ->
      Map.put(a, apply(__MODULE__, fun, [k]), convert_keys(v, fun))
    end
  end

  defp convert_keys(list, fun) when is_list(list) do
    Enum.map list, &convert_keys(&1, fun)
  end

  defp convert_keys(other, _fun), do: other

  def camelize_key(key),   do: Inflex.camelize(key, :lower)
  def underscore_key(key), do: Inflex.underscore(key)
end
