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
    use JaSerializer

    serialize "posts" do
      attributes [:id, :title, :body, :is_published]
      has_one    :author, type: "people"
      has_many   :comments, type: "comments"
    end

    def author(post),       do: post.author.id
    def is_published(post), do: post.published

    def comments(post) do
      Enum.filter_map Store.comments, &(&1.post_id == post.id), &(&1.id)
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:fetch_all, :fetch_one], ecto: false
    plug :resource

    def serializer, do: PostSerializer

    def fetchable(_c), do: Store.posts

    def fetch_one(_c, id) do
      Enum.find Store.posts, &(&1.id == String.to_integer(id))
    end
  end

  defmodule Router do
    use Relax.Router
    plug :route

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

    assert [p1, _p2] = json["data"]
    assert is_binary  p1["id"]
    assert p1["type"] == "posts"
    assert is_binary  p1["attributes"]["title"]
    assert is_binary  p1["attributes"]["body"]
    assert is_boolean p1["attributes"]["is-published"]

    assert [cid1, cid2] = p1["relationships"]["comments"]["data"]
    assert is_binary cid1["id"]
    assert cid1["type"] == "comments"
    assert is_binary cid2["id"]
    assert cid2["type"] == "comments"

    author = p1["relationships"]["author"]["data"]
    assert is_binary author["id"]
    assert author["type"] == "people"
  end

  test "GET /v1/posts/:id" do
    [post | _] = Store.posts

    conn = conn("GET", "/v1/posts/#{post.id}", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    pj = json["data"]

    assert to_string(post.id) == pj["id"]
    assert "posts"        == pj["type"]
    assert post.title     == pj["attributes"]["title"]
    assert post.body      == pj["attributes"]["body"]
    assert post.published == pj["attributes"]["is-published"]

    assert [cid1, cid2] = pj["relationships"]["comments"]["data"]
    assert is_binary cid1["id"]
    assert cid1["type"] == "comments"
    assert is_binary cid2["id"]
    assert cid2["type"] == "comments"

    author = pj["relationships"]["author"]["data"]
    assert is_binary author["id"]
    assert author["type"] == "people"
  end

  test "GET /v1/posts/:wrong_id" do
    conn = conn("GET", "/v1/posts/9999999999", nil, [])
    response = Router.call(conn, [])
    assert 404 = response.status
  end
end
