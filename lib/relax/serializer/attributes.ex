defmodule Relax.Serializer.Attributes do

  def get(serializer, model, conn) do
    Enum.reduce serializer.__attributes, %{}, fn(attr, results) ->
      Map.put(results, attr, apply(serializer, attr, [model, conn]))
    end
  end
end
