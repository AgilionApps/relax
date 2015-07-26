defmodule Relax.EctoResource.Update do
  use Behaviour

  @type updateable :: map
  @type id :: integer | String.t

  defcallback update(Plug.Conn.t, updateable, map) :: updateable | Plug.Conn.t
  defcallback update_resource(Plug.Conn.t, id) :: Plug.Conn.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.EctoResource.Update
      @behaviour Relax.EctoResource.FetchOne
      @behaviour Relax.EctoResource.Fetchable
      @behaviour Relax.EctoResource.PermittedParams

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
            attrs = Relax.EctoResource.PermittedParams.filter(conn, [
              attributes: apply(__MODULE__, :permitted_attributes, [:update, conn]),
              relations: apply(__MODULE__, :permitted_relations, [:update, conn]),
            ])
            conn
            |> update(model, attrs)
            |> Relax.EctoResource.Update.respond(conn, __MODULE__)
        end
      end

      defoverridable [update_resource: 2]
    end
  end

  @doc false
  def halt_not_found(%Plug.Conn{} = conn), do: conn
  def halt_not_found(nil, conn),           do: Relax.Responders.not_found(conn)
  def halt_not_found(model, _conn),        do: model

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
    Relax.Responders.send_json(conn, 200, model, resource)
  end

  defp invalid(conn, errors, resource) do
    Relax.Responders.send_json(conn, 422, errors, resource)
  end
end
