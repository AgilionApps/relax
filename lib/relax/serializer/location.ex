defmodule Relax.Serializer.Location do
  defmacro path(path) do
    quote do: @location unquote(path)
  end

  def generate(model, path) do
    {:ok, root_url} = Application.fetch_env(:json_api, :root_url)
    path = String.split(path, "/")
      |> Enum.map_join "/", &convert_path(&1, model)
    root_url <> path
  end

  def convert_path(":" <> frag, model) do
    "#{Map.get(model, String.to_atom(frag))}"
  end

  def convert_path(frag, _model), do: frag
end
