defmodule Relax.Params do

  defmacro __using__(_) do
    quote do
      import Relax.Params, only: [filter_params: 3, filter_params: 2]
    end
  end

  defmacro filter_params(conn, allow, do: block) do
    quote do
      var!(params) = Relax.Params.filter_params(unquote(conn), unquote(allow))
      unquote(block)
    end
  end

  def filter_params(conn, {key, allowed}) when is_atom(key) do
    filter_params(conn, {Atom.to_string(key), allowed})
  end

  def filter_params(conn, {key, allowed}) do
    Enum.reduce allowed, %{}, &get_filtered_value(&1, &2, conn.params[key])
  end

  defp get_filtered_value({key, path}, accum, raw) do
    value = get_nested_value(raw, String.split(path, "."))
    Map.put(accum, key, value)
  end

  defp get_filtered_value(key, accum, raw) do
    Map.put(accum, key, Map.get(raw, Atom.to_string(key)))
  end

  defp get_nested_value(val, []), do: val

  defp get_nested_value(%{} = map, [h | t]) do
    get_nested_value(Map.get(map, h), t)
  end

  defp get_nested_value(_not_map, _list), do: nil
end
