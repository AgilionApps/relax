defmodule Relax.Resource.Update do
  use Behaviour

  @moduledoc """
  Include in your resource to respond to PUT /:id and PATCH /:id.

  Typically brought into your resource via `use Relax.Resource`.

  Update defines two callback behaviours, one of which (`update/2`) must be
  implemented.

  In addition this module includes the behaviours

  * `Relax.Resource.FetchOne` - to find the model to update.
  * `Relax.Resource.Fetchable` - to find the model to update.
  * `Relax.Resource.PermittiedParams` - to whitelist the attributes for update.
  """

  @type updateable :: map
  @type id :: integer | String.t

  @doc"""
  Update (or attempt to update) an existing record.

  Receives the conn, the model as found by `fetch_one/2` and the whitelisted
  and formatted params. See Relax.Resource.PermittedParams for more information
  on whitelisting params.

  Update often returns an Ecto.Changeset, which will be saved and formated as
  is appropriate.

      def update(_conn, post, attributes) do
        Models.Post.changeset(post, attributes)
      end

  Alternatively a tuple of either `{:ok, model}` or `{:error, errors}` can be
  returned.

  A conn may also be returned:

      def update(conn), do: halt send_resp(conn, 401, "nope")

  """
  defcallback update(Plug.Conn.t, updateable, map) :: updateable | Plug.Conn.t

  @doc """
  This callback can be used to completely override the update action.

  It accepts a Plug.Conn and must return a Plug.Conn.t
  """
  defcallback update_resource(Plug.Conn.t, id) :: Plug.Conn.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Relax.Resource.Update
      @behaviour Relax.Resource.FetchOne
      @behaviour Relax.Resource.Fetchable
      @behaviour Relax.Resource.PermittedParams

      def do_resource(conn, "PATCH", [id]), do: update_resource(conn, id)
      def do_resource(conn, "PUT", [id]), do: update_resource(conn, id)

      def update_resource(conn, id) do
        model = conn
                |> fetch_one(id)
                |> Relax.Resource.FetchOne.execute_query(id, __MODULE__)
                |> Relax.Resource.Update.halt_not_found(conn)

        case model do
          %Plug.Conn{} = conn -> conn
          model ->
            attrs = Relax.Resource.PermittedParams.filter(conn, [
              attributes: apply(__MODULE__, :permitted_attributes, [:update, conn]),
              relations: apply(__MODULE__, :permitted_relations, [:update, conn]),
            ])
            conn
            |> update(model, attrs)
            |> Relax.Resource.Update.respond(conn, __MODULE__)
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
