defmodule Relax.Integration.RelationshipLinksTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule Store do
    @authors Forge.author_list(1)
    @posts Forge.post_list(2)
    @comments Enum.flat_map(@posts, &(Forge.comment_list(2, post_id: &1.id)))
    def authors,  do: @authors
    def posts,    do: @posts
    def comments, do: @comments
  end

  defmodule AuthorSerializer do
    use JaSerializer
    serialize "authors" do
      attributes [:id, :name, :email]
    end
  end

  defmodule PostSerializer do
    use JaSerializer
    serialize "posts" do
      attributes [:id, :title, :body]
      has_one    :author,   link: "/v1/authors/:author_id"
      has_many   :comments, link: "/v1/posts/:id/comments"
    end
    def author_id(post, _conn), do: post.author.id
  end

  defmodule CommentSerializer do
    use JaSerializer
    serialize "comments" do
      attributes [:id, :body]
      has_one    :post, link: "/v1/posts/:post", field: :post_id
    end
  end

  defmodule AuthorsResource do
    use Relax.Resource, only: [:fetch_one], ecto: false
    plug :resource

    def serializer, do: AuthorSerializer

    def fetch_one(_conn, id) do
      Enum.find Store.authors, &(&1.id == String.to_integer(id))
    end
  end

  defmodule PostsResource do
    use Relax.Resource, only: [:fetch_one], ecto: false
    plug :resource

    def serializer, do: PostSerializer

    def fetch_one(_conn, id) do
      Enum.find Store.posts, &(&1.id == String.to_integer(id))
    end
  end

  defmodule PostCommentsResource do
    use Relax.Resource, only: [:fetch_all], ecto: false
    plug :resource

    def serializer, do: CommentSerializer

    def fetchable(_conn), do: Store.comments

    def filter("posts", comments, id) do
      id = String.to_integer(id)
      Enum.filter(comments, &(&1.post_id == id))
    end
  end

  defmodule Router do
    use Relax.Router
    plug :route

    version :v1 do
      resource :authors, AuthorsResource
      resource :posts, PostsResource do
        resource :comments, PostCommentsResource
      end
    end
  end

  test "GET /v1/authors/:id" do
    [author | _] = Store.authors

    conn = conn("GET", "/v1/authors/#{author.id}", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    steve = json["data"]
    refute Map.has_key?(steve, "relationships")
  end

  test "GET /v1/posts/:id" do
    [post | _] = Store.posts

    conn = conn("GET", "/v1/posts/#{post.id}", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    pj = json["data"]
    assert "/v1/posts/#{post.id}/comments" == pj["relationships"]["comments"]["links"]["related"]
    assert "/v1/authors/#{post.author.id}" == pj["relationships"]["author"]["links"]["related"]
  end

  test "GET /v1/posts/:id/comments" do
    [post | _] = Store.posts

    conn = conn("GET", "/v1/posts/#{post.id}/comments", nil, [])
    response = Router.call(conn, [])
    assert 200 = response.status
    assert ["application/vnd.api+json"] = get_resp_header(response, "content-type")
    assert {:ok, json} = Poison.decode(response.resp_body)

    assert [c1, _c2] = json["data"]
    assert is_binary c1["id"]
    assert is_binary c1["attributes"]["body"]
    assert "/v1/posts/#{post.id}" == c1["relationships"]["post"]["links"]["related"]
  end
end
