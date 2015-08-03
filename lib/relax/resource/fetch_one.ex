defmodule Relax.Resource.FetchOne do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to GET /:id.

  Typically brought into your resource via `use Relax.Resource`.

  FetchOne defines two callback behaviours, both of which have a default,
  overrideable implementation.

  In addition this module uses `Relax.Resource.Fetchable`, for shared model 
  lookup logic with Relax.Resource.FetchAll.
  """

  @type id :: integer | String.t

  @doc """
  Find a resource to return.

  This should return a struct to be formatted. Nil responses will trigger 404s.

  Examples:

      # Ecto based on query:
      def fetch_one(_conn, id), do: MyApp.Repo.get!(MyApp.Models.Post, id)

      # Return model limited to the current_user
      def fetch_one(conn), do 
        fetchable(conn)
        |> MyApp.Repo.get(id)
      end

  A conn may also be returned:

      def fetch_one(conn), do: halt send_resp(conn, 401, "no post for you")

  The default behaviour leverages `fetchable/1` and attempts to find via Ecto
  if possible.
  """
  defcallback fetch_one(Plug.Conn.t, id) :: Plug.Conn.t | map

  @doc """
  This callback can be used to completely override the fetch_one action.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback fetch_one_resource(Plug.Conn.t, id) :: Plug.Conn.t

  defmacro __using__(_opts) do
    quote location: :keep do
      use Relax.Resource.Fetchable
      @behaviour Relax.Resource.FetchOne

      def do_resource(conn, "GET", [id]) do
        fetch_one_resource(conn, id)
      end

      def fetch_one_resource(conn, id) do
        conn
        |> fetch_one(id)
        |> Relax.Resource.FetchOne.respond(conn, __MODULE__)
      end

      def fetch_one(conn, id) do
        conn
        |> fetchable
        |> Relax.Resource.FetchOne.execute_query(id, __MODULE__)
      end

      defoverridable [fetch_one_resource: 2, fetch_one: 2]
    end
  end

  @doc false
  def execute_query(query, id, resource) do
    module = resource.model
    case query do
      nil               -> nil
      %Ecto.Query{} = q -> resource.repo.get(q, id)
      ^module       = q -> resource.repo.get(q, id)
      other             -> other
    end
  end

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(nil, conn, _resource) do
    Relax.Responders.not_found(conn)
  end
  def respond(model, conn, resource) do
    Relax.Responders.send_json(conn, 200, model, resource)
  end
end
