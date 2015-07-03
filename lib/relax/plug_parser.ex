defmodule Relax.PlugParser do
  @behaviour Plug.Parsers
  alias Plug.Conn

  def parse(conn, "application", "vnd.api+json", _headers, opts) do
    parse(conn, opts)
  end

  # Allow "normal" json requests to be handled as well.
  def parse(conn, "application", "json", _headers, opts) do
    parse(conn, opts)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp parse(conn, opts) do
    conn
    |> Conn.read_body(opts)
    |> decode
  end

  defp decode({:more, _, conn}) do
    {:error, :too_large, conn}
  end

  defp decode({:ok, "", conn}) do
    {:ok, %{}, conn}
  end

  defp decode({:ok, body, conn}) do
    decoded = body
              |> Poison.decode!
              |> underscore
    {:ok, decoded, conn}
  end

  defp underscore(nil), do: nil

  defp underscore(%{"data" => data} = req) do
    Map.merge(req, %{
      "data" => %{
        "attributes" => underscore(data["attributes"]),
        "relationships" => underscore(data["relationships"])
      }
    })
  end

  defp underscore(map) when is_map(map) do
    Enum.reduce map, %{}, fn({k, v}, a) ->
      Map.put(a, underscore(k), v)
    end
  end

  defp underscore(string) when is_binary(string) do
    String.replace(string, ~r/\-/, "_")
  end
end
