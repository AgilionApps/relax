defmodule Relax.Resource.Delete do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to DELETE /:id

  Typically brought into your resource via `use Relax.Resource`.

  Update defines two callback behaviours, one of which (`delete/2`) must be
  implemented.

  In addition this module includes the behaviours:

  * `Relax.Resource.FetchOne` - to find the model to update.
  * `Relax.Resource.Fetchable` - to find the model to update.
  """

  @type id :: integer | String.t

  @doc """
  Delete a record.

  Receives the conn and the model as found by `fetch_one/2`.

      def delete(_conn, post) do
        MyApp.Repo.delete!(post)
      end

  A conn may also be returned:

      def delete(conn), do: halt send_resp(conn, 401, "nope")

  """
  defcallback delete(Plug.Conn.t, map) :: Plug.Conn.t | {atom, map} | map

  @doc """
  This callback can be used to completely override the delete action.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback delete_resource(Plug.Conn.t, id) :: Plug.Conn.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.Resource.Delete
      @behaviour Relax.Resource.FetchOne
      @behaviour Relax.Resource.Fetchable

      def do_resource(conn, "DELETE", [id]) do
        delete_resource(conn, id)
      end

      def delete_resource(conn, id) do
        model = conn
                |> fetch_one(id)
                |> Relax.Resource.FetchOne.execute_query(id, __MODULE__)
                |> Relax.Resource.Delete.halt_not_found(conn)

        case model do
          %Plug.Conn{} = conn -> conn
          model ->
            conn
            |> delete(model)
            |> Relax.Resource.Delete.respond(conn, __MODULE__)
        end
      end

      defoverridable [delete_resource: 2]
    end
  end

  @doc false
  def halt_not_found(%Plug.Conn{} = conn), do: conn
  def halt_not_found(nil, conn),           do: Relax.Responders.not_found(conn)
  def halt_not_found(model, _conn),        do: model

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond({:error, errors}, conn, resource) do
    Relax.Responders.send_json(conn, 422, errors, resource)
  end
  def respond(_model, conn, resource) do
    deleted(conn)
  end

  defp deleted(conn) do
    conn
    |> Plug.Conn.send_resp(200, "")
    |> Plug.Conn.halt
  end
end
