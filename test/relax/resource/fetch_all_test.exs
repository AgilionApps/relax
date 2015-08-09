defmodule Relax.Resource.FetchAllTest do
  use ExUnit.Case

  defmodule Article do
    defstruct [:title, :published]
  end

  defmodule InspectSerializer do
    def format(obj, _, _), do: obj
  end

  defmodule ArticlesResource do
    use Relax.Resource.FetchAll

    def model, do: Article
    def serializer, do: InspectSerializer

    def fetch_all(_conn) do
      [
        %Article{title: "one", published: true},
        %Article{title: "two", published: true},
        %Article{title: "three", published: false}
      ]
    end

    def filter("published", articles, _val) do
      Enum.filter(articles, &(&1.published))
    end
  end

  test "return the fetch_all value with no filter" do
    conn = Plug.Test.conn("GET", "/", []) |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    assert [_, _, _] = Poison.decode!(json)
  end

  test "apply defined filters" do
    conn = Plug.Test.conn("GET", "/?filter[published]=true", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    assert [_, _] = Poison.decode!(json)
  end

  test "ignore undefined filters" do
    conn = Plug.Test.conn("GET", "/?filter[foo]=true", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    assert [_, _, _] = Poison.decode!(json)
  end
end
