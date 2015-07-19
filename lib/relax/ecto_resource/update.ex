defmodule Relax.EctoResource.Update do
  use Behaviour

  @type updateable :: Plug.Conn.t | {atom, any} | module | Ecto.Query.t
  @type fetchable :: module | Ecto.Query.t | map
  @type id :: integer | String.t

  defcallback fetch_one(Plug.Conn.t, id) :: Plug.Conn.t | fetchable
  defcallback update(Plug.Conn.t, map, map) :: updateable
  defcallback update_resource(Plug.Conn.t, id) :: Plug.Conn.t

  @doc false
  defmacro __using__(opts) do
    quote location: :keep do
      @behaviour Relax.EctoResource.Update

      def do_resource(conn, "PUT", [id]) do
        update_resource(conn, id)
      end

      def update_resource(conn, id) do
        model = conn
        |> fetch_one(id)
        |> Relax.EctoResource.FetchOne.execute_query(id, __MODULE__)
        |> Relax.EctoResource.Update.halt_not_found(conn)

        case model do
          %Plug.Conn{} = conn -> conn
          model ->
            attributes = Relax.EctoResource.filter_attributes(conn, unquote(opts))
            conn
            |> update(model, attributes)
            |> Relax.EctoResource.Update.respond(conn, __MODULE__)
        end
      end

      defoverridable [update_resource: 2]
    end
  end

  @doc false
  def halt_not_found(%Plug.Conn{} = conn), do: conn
  def halt_not_found(nil, conn) do
      conn
      |> Plug.Conn.send_resp(404, "")
      |> Plug.Conn.halt
  end
  def halt_not_found(model, _conn), do: model

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(%Ecto.Changeset{} = change, conn, resource) do
    if change.valid? do
      model = resource.repo.update!(change)
      updated(conn, model, resource)
    else
      invalid(conn, change.errors, resource)
    end
  end
  def respond({:error, errors}, conn, resource) do
    invalid(conn, errors, resource)
  end
  def respond({:ok, model}, conn, resource) do
    updated(conn, model, resource)
  end
  def respond(model, conn, resource) do
    updated(conn, model, resource)
  end

  defp updated(conn, model, resource) do
    conn
    |> Relax.Responders.send_json(200, model, resource.serializer)
    |> Plug.Conn.halt
  end

  defp invalid(conn, errors, resource) do
    conn
    |> Relax.Responders.send_json(422, errors, resource.error_serializer)
    |> Plug.Conn.halt
  end
end
