defmodule Relax.Integration.CompoundDocumentTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Store do
    @posts Forge.post_list(2)
    @comments Enum.flat_map(@posts, &(Forge.comment_list(2, post_id: &1.id)))
    def posts,    do: @posts
    def comments, do: @comments
  end

  defmodule AuthorSerializer do
    use JaSerializer
    serialize "authors" do
      attributes [:id, :name, :email]
    end
  end

  defmodule CommentSerializer do
    use JaSerializer
    serialize "comments" do
      attributes [:id, :body]
      has_one    :post, link: "/v1/posts/:post", field: :post_id
    end
  end

  defmodule PostSerializer do
    use JaSerializer
    serialize "posts" do
      attributes [:id, :title, :body]
      has_one    :author,   include: AuthorSerializer
      has_many   :comments, include: CommentSerializer
    end
    def author(post, _conn), do: post.author
    def comments(post, _conn) do
      Enum.filter(Store.comments, &(&1.post_id == post.id))
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:find_all]
    plug :match
    plug :dispatch

    serializer PostSerializer

    def find_all(conn), do: okay(conn, Store.posts)
  end

  defmodule Router do
    use Relax.Router
    plug :match
    plug :dispatch

    version :v2 do
      resource :posts, PostsResource
    end
  end

  test "GET /v2/posts" do
    conn = conn("GET", "/v2/posts", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    assert [p1, _p2] = json["data"]
    assert is_binary p1["id"]
    assert is_binary p1["attributes"]["title"]
    assert [c1id, c2id] = p1["relationships"]["comments"]["data"]
    assert is_binary c1id["id"]
    assert is_binary c2id["id"]
    assert c1id["type"] == "comments"
    assert c2id["type"] == "comments"

    assert [c1, _c2, _c3, _c4] = Enum.filter(json["included"], &(&1["type"] == "comments"))
    assert is_binary c1["id"]
    assert is_binary c1["attributes"]["body"]

    assert [a1, _a2] = Enum.filter(json["included"], &(&1["type"] == "authors"))
    assert is_binary a1["id"]
    assert is_binary a1["attributes"]["email"]
  end
end
