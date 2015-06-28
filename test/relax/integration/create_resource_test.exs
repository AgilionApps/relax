defmodule Relax.Integration.CreateResourceTest do
  use ExUnit.Case, async: true
  use Plug.Test

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

  defmodule PostSerializer do
    use JaSerializer
    serialize "posts" do
      location "/v1/posts/:id"
      attributes [:id, :title, :body]
      has_one    :author, field: :author_id, type: "person"
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:create]
    plug :match
    plug :dispatch

    serializer PostSerializer

    def create(conn) do
      case Post.create(params(conn)) do
        {:ok,    post}   -> created(conn, post)
        {:error, errors} -> invalid(conn, errors)
      end
    end

    def params(%{params: params}) do
      params["data"]["attributes"]
      |> Dict.take(["title", "body"])
      |> Dict.put("author_id", params["data"]["relationships"]["author"]["data"]["id"])
    end
  end

  defmodule Router do
    use Relax.Router
    plug :match
    plug :dispatch

    version :v1 do
      resource :posts, PostsResource
    end
  end

  test "POST /v1/posts - valid params" do
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
    assert is_binary json["data"]["id"]
    assert "foo" == json["data"]["attributes"]["title"]
    assert "42" == json["data"]["relationships"]["author"]["data"]["id"]
    assert "person" == json["data"]["relationships"]["author"]["data"]["type"]
    assert "/v1/posts/1234" in get_resp_header(response, "Location")
  end

  test "POST /v1/posts - invalid params" do
    request = %{
      "data" => %{
        "type" => "posts",
        "attributes" => %{
          "body"    => "bar",
        }
      }
    }

    {:ok, body} = Poison.encode(request, string: true)
    response = conn("POST", "/v1/posts/", body)
                |> put_req_header("content-type", "application/vnd.api+json")
                |> Router.call([])

    assert 422 = response.status
  end

end
