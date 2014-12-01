defmodule Relax.Serializer.Location do
  defmodule RootUrlMustBeSet do
    defexception message: """
      To use url relationships you must set the application :relax, :root_url.

      Try adding the following to your config/config.exs file:

          config :relax,
            root_url: "http://localhost:4200"
    """
  end

  defmacro path(path) do
    quote do: @location unquote(path)
  end

  def generate(model, serializer, conn, path) do
    case Application.fetch_env(:relax, :root_url) do
      :error          -> raise RootUrlMustBeSet
      {:ok, root_url} -> do_generate(model, serializer, conn, path, root_url)
    end
  end

  defp do_generate(model, serializer, conn, path, root_url) do
    interpolated = String.split(path, "/")
                    |> Enum.map_join "/", &convert_path(&1, model, serializer, conn)
    root_url <> interpolated
  end

  defp convert_path(":" <> frag, model, serializer, conn) do
    "#{apply(serializer, String.to_atom(frag), [model, conn])}"
  end

  defp convert_path(frag, _model, _serializer, _conn), do: frag
end
