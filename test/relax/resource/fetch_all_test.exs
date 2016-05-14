defmodule Relax.Resource.FetchAllTest do
  use ExUnit.Case

  defmodule Article do
    defstruct [:title, :published, :created]
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
        %Article{title: "one", published: true, created: 1},
        %Article{title: "two", published: true, created: 2},
        %Article{title: "three", published: false, created: 3}
      ]
    end

    def filter("published", articles, _val) do
      Enum.filter(articles, &(&1.published))
    end

    def sort("created", collection, :asc) do
      Enum.sort_by(collection, &(&1.created))
    end

    def sort("created", collection, :desc) do
      sort("created", collection, :asc) |> Enum.reverse
    end

    def sort("published", collection, :asc) do
      Enum.sort_by(collection, &(&1.published))
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

  test "sorts when requested to" do
    conn = Plug.Test.conn("GET", "/?sort=created", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    json = Poison.decode!(json, keys: :atoms)
    assert [%{created: 1}, %{created: 2}, %{created: 3}] = json
  end

  test "sorts descending when requested to" do
    conn = Plug.Test.conn("GET", "/?sort=-created", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    json = Poison.decode!(json, keys: :atoms)
    assert [%{created: 3}, %{created: 2}, %{created: 1}] = json
  end

  test "sorts multiple when requested to" do
    conn = Plug.Test.conn("GET", "/?sort=-created,published", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    json = Poison.decode!(json, keys: :atoms)
    assert [%{created: 3}, %{created: 1}, %{created: 2}] = json
  end

  test "paginate by 1" do
    conn = Plug.Test.conn("GET", "/?page=1&size=1", [])
            |> Plug.Conn.fetch_query_params
    %{resp_body: json} = ArticlesResource.fetch_all_resources(conn)
    json = Poison.decode!(json, keys: :atoms)
    assert [%{created: 1, published: true, title: "one"}] = json
  end
end
