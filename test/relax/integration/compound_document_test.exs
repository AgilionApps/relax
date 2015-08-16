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
    def type, do: "authors"
    attributes [:id, :name, :email]
  end

  defmodule CommentSerializer do
    use JaSerializer
    def type, do: "comments"
    attributes [:id, :body]
    has_one    :post, link: "/v1/posts/:post", field: :post_id
  end

  defmodule PostSerializer do
    use JaSerializer
    def type, do: "posts"
    attributes [:id, :title, :body]
    has_one    :author,   include: AuthorSerializer
    has_many   :comments, include: CommentSerializer
    def author(post, _conn), do: post.author
    def comments(post, _conn) do
      Enum.filter(Store.comments, &(&1.post_id == post.id))
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:fetch_all], ecto: false

    plug :resource

    def serializer, do: PostSerializer

    def fetchable(_conn), do: Store.posts
  end

  defmodule Router do
    use Relax.Router
    plug :route

    version :v2 do
      resource :posts, PostsResource
    end
  end

  @ct "application/vnd.api+json"

  @tag timeout: 10000
  test "GET /v2/posts" do
    response = conn("GET", "/v2/posts")
                |> put_req_header("accept", @ct)
                |> Router.call([])

    assert 200 = response.status
    assert [@ct] = get_resp_header(response, "content-type")
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
