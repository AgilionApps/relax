defmodule Relax.Resource.Create do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to POST /.

  Typically brought into your resource via `use Relax.Resource`.

  Create defines two callback behaviours, one of which (`create/2`) must be
  implemented.

  In addition this module includes the behaviour
  `Relax.Resource.PermittedParams` which is used to whitelist and format
  jsonapi.org formatted params for use in structs.
  """

  @type createable :: Plug.Conn.t | {atom, any} | module | Ecto.Changeset.t

  @doc """
  Create (or attempt to create) a new record.

  Receives the conn and the whitelisted and formatted params. See
  Relax.Resource.PermittedParams for more information on whitelisting params.

  This often returns an Ecto.Changeset, which will be saved and formated as is
  appropriate.

      def create(_conn, attributes) do
        Models.Post.changeset(%Models.Post{}, attributes)
      end

  Alternatively a tuple of either `{:ok, model}` or `{:error, errors}` can be
  returned.

  A conn may also be returned:

      def create(conn), do: halt send_resp(conn, 401, "nope")

  """
  defcallback create(Plug.Conn.t, map) :: createable

  @doc """
  This callback can be used to completely override the create action.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback create_resource(Plug.Conn.t) :: Plug.Conn.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.Resource.Create
      @behaviour Relax.Resource.PermittedParams

      def do_resource(conn, "POST", []) do
        create_resource(conn)
      end

      def create_resource(conn) do
        attrs = Relax.Resource.PermittedParams.filter(conn, [
          attributes: apply(__MODULE__, :permitted_attributes, [:create, conn]),
          relations: apply(__MODULE__, :permitted_relations, [:create, conn]),
        ])
        conn
        |> create(attrs)
        |> Relax.Resource.Create.respond(conn, __MODULE__)
      end

      defoverridable [create_resource: 1]
    end
  end

  @doc false
  def respond(%Plug.Conn{} = conn, _old_conn, _resource), do: conn
  def respond(%Ecto.Changeset{} = change, conn, resource) do
    if change.valid? do
      change |> resource.repo.insert |> respond(conn, resource)
    else
      Relax.Responders.send_json(conn, 422, change.errors, resource)
    end
  end
  def respond({:error, errors}, conn, resource) do
    Relax.Responders.send_json(conn, 422, errors, resource)
  end
  def respond({:ok, model}, conn, resource) do
    Relax.Responders.send_json(conn, 201, model, resource)
  end
  def respond(model, conn, resource) do
    Relax.Responders.send_json(conn, 201, model, resource)
  end
end
