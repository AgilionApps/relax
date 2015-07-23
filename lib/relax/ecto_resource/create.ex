defmodule Relax.EctoResource.Create do
  use Behaviour

  @type createable :: Plug.Conn.t | {atom, any} | module | Ecto.Query.t
  defcallback create(Plug.Conn.t, map) :: createable
  defcallback create_resource(Plug.Conn.t) :: Plug.Conn.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.EctoResource.Create
      @behaviour Relax.EctoResource.PermittedParams

      def do_resource(conn, "POST", []) do
        create_resource(conn)
      end

      def create_resource(conn) do
        attrs = Relax.EctoResource.PermittedParams.filter(conn, [
          attributes: apply(__MODULE__, :permitted_attributes, [:create, conn]),
          relations: apply(__MODULE__, :permitted_relations, [:create, conn]),
        ])
        conn
        |> create(attrs)
        |> Relax.EctoResource.Create.respond(conn, __MODULE__)
      end

      defoverridable [create_resource: 1]
    end
  end

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(%Ecto.Changeset{} = change, conn, resource) do
    if change.valid? do
      model = resource.repo.insert!(change)
      conn
      |> Relax.Responders.send_json(201, model, resource.serializer)
      |> Plug.Conn.halt
    else
      conn
      |> Relax.Responders.send_json(422, change.errors, resource.error_serializer)
      |> Plug.Conn.halt
    end
  end
  def respond({:error, errors}, conn, resource) do
    conn
    |> Relax.Responders.send_json(422, errors, resource.error_serializer)
    |> Plug.Conn.halt
  end
  def respond({:ok, model}, conn, resource) do
    conn
    |> Relax.Responders.send_json(201, model, resource.serializer)
    |> Plug.Conn.halt
  end
  def respond(model, resource, conn) do
    conn
    |> Relax.Responders.send_json(201, model, resource.serializer)
    |> Plug.Conn.halt
  end
end
