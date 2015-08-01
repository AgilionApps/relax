defmodule Relax.Resource.CreateTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Ecto.Changeset do
    defstruct name: 'blank'
  end

  defmodule Post do
    def create(%{"title" => t, "body" => b, "author_id" => a} = atts)
        when is_binary(t) and is_binary(b) and is_binary(a) do
      result = atts
        |> Enum.reduce(%{}, fn({k, v}, a) -> Map.put(a, String.to_atom(k), v) end)
        |> Dict.put(:id, 1234)
      {:ok, result}
    end

    def create(_atts), do: {:error, %{error: "Invalid attributes"}}
  end

  defmodule Serializer do
    def format(obj, _conn, nil), do: obj
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:create], ecto: false
    plug :resource

    def serializer, do: Serializer
    def error_serializer, do: Serializer

    def create(_c, attributes = %{}) do
      Post.create(attributes)
    end

    def permitted_attributes(:create, _conn), do: [:title, :body]
    def permitted_relations(:create, _conn), do: [:author]
  end

  defmodule Router do
    use Relax.Router
    plug :route

    version :v1 do
      resource :posts, PostsResource
      resource :users, UsersResource
    end
  end

  test "returns 201 with the model json data" do
    request = %{
      "data" => %{
        "type" => "posts",
        "attributes" => %{
          "title"   => "foo",
          "body"    => "bar",
          "naughty" => "hacker"
        },
        "relationships" => %{
          "author" => %{
            "data" => %{"id" => "42", "type" => "person"}
          }
        }
      }
    }

    {:ok, body} = Poison.encode(request, string: true)
    response = conn("POST", "/v1/posts/", body)
                |> put_req_header("content-type", "application/vnd.api+json")
                |> Router.call([])

    assert 201 = response.status
    assert {:ok, json} = Poison.decode(response.resp_body)
    assert is_binary json["title"]
    assert is_binary json["body"]
    assert is_binary json["author_id"]
    refute is_binary json["naughty"]
  end

  test "returns 422 with a struct with errors" do
    request = %{
      "data" => %{
        "type" => "posts",
        "attributes" => %{}
      }
    }

    {:ok, body} = Poison.encode(request, string: true)
    response = conn("POST", "/v1/posts/", body)
                |> put_req_header("content-type", "application/vnd.api+json")
                |> Router.call([])

    assert 422 = response.status
    assert {:ok, errors} = Poison.decode(response.resp_body)
    assert %{"error" => "Invalid attributes"} == errors
  end
end
