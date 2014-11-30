defmodule Relax.Integration.SerializeIdsTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Store do
    @posts Forge.post_list(2)
    @comments Enum.flat_map(@posts, &(Forge.comment_list(2, post_id: &1.id)))

    def posts,    do: @posts
    def comments, do: @comments
  end

  defmodule PostSerializer do
    use Relax.Serializer

    serialize "posts" do
      attributes [:id, :title, :body, :is_published]
      has_one    :author
      has_many   :comments
    end

    def author(post, _conn),       do: post.author.id
    def is_published(post, _conn), do: post.published

    def comments(post, _conn) do
      Enum.filter_map Store.comments, &(&1.post_id == post.id), &(&1.id)
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:find_all, :find_one]
    plug :match
    plug :dispatch

    serializer PostSerializer

    def find_all(conn), do: okay(conn, Store.posts)

    def find_one(conn, id) do
      case Enum.find Store.posts, &(&1.id == String.to_integer(id)) do
        nil   -> not_found(conn)
        posts -> okay(conn, posts)
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


  test "GET /v1/posts" do
    conn = conn("GET", "/v1/posts", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    assert [p1, _p2] = json["posts"]
    assert is_integer p1["id"]
    assert is_binary  p1["title"]
    assert is_binary  p1["body"]
    assert is_boolean p1["isPublished"]

    assert [cid1, cid2] = p1["links"]["comments"]
    assert is_integer cid1
    assert is_integer cid2

    author_id = p1["links"]["author"]
    assert is_integer author_id
  end

  test "GET /v1/posts/:id" do
    [post | _] = Store.posts

    conn = conn("GET", "/v1/posts/#{post.id}", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    pj = json["posts"]

    assert post.id        == pj["id"]
    assert post.title     == pj["title"]
    assert post.body      == pj["body"]
    assert post.published == pj["isPublished"]

    assert [cid1, cid2] = pj["links"]["comments"]
    assert is_integer cid1
    assert is_integer cid2

    author_id = pj["links"]["author"]
    assert is_integer author_id
  end

  test "GET /v1/posts/:wrong_id" do
    conn = conn("GET", "/v1/posts/9999999999", nil, [])
    response = Router.call(conn, [])
    assert 404 = response.status
  end
end
