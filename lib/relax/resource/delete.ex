defmodule Relax.Resource.Delete do
  use Behaviour

  @moduledoc """

  """

  @type id :: integer | String.t

  defcallback delete(Plug.Conn.t, map) :: Plug.Conn.t | {atom, map} | map
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
