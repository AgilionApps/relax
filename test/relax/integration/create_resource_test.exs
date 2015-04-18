defmodule Relax.Integration.CreateResourceTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Post do
    def create(%{title: t, body: b, author_id: a} = atts)
        when is_binary(t) and is_binary(b) and is_integer(a) do
      {:ok, Dict.put(atts, :id, 1234)}
    end

    def create(_atts), do: {:error, %{error: "Invalid attributes"}}
  end

  defmodule PostSerializer do
    use Relax.Serializer
    path "/v1/posts/:id"
    serialize "posts" do
      attributes [:id, :title, :body]
      has_one    :author
    end
    def author(post, _conn), do: post.author_id
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:create]
    plug :match
    plug :dispatch

    serializer PostSerializer

    @allowed_params {:posts, [:title, :body, {:author_id, "links.author"}]}

    def create(conn) do
      params = filter_params(conn, @allowed_params)
      case Post.create(params) do
        {:ok,    post}   -> created(conn, post)
        {:error, errors} -> invalid(conn, errors)
      end
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
      "posts" => %{
        "title"   => "foo",
        "body"    => "bar",
        "naughty" => "hacker",
        "links"   => %{ "author" => 42 }
      }
    }

    {:ok, body} = Poison.encode(request, string: true)
    response = conn("POST", "/v1/posts/", body)
                |> put_req_header("content-type", "application/vnd.api+json")
                |> Router.call([])

    assert 201 = response.status
    assert {:ok, json} = Poison.decode(response.resp_body)
    assert is_integer json["posts"]["id"]
    assert "foo" == json["posts"]["title"]
    assert 42 == json["posts"]["links"]["author"]
  end

  test "POST /v1/posts - invalid params" do
    request = %{
      "posts" => %{
        "body"    => "bar",
      }
    }

    {:ok, body} = Poison.encode(request, string: true)
    response = conn("POST", "/v1/posts/", body)
                |> put_req_header("content-type", "application/vnd.api+json")
                |> Router.call([])

    assert 422 = response.status
  end

end
