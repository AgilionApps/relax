defmodule Relax.EctoResource do
  use Behaviour

  @moduledoc """
  A DSL to help build JSONAPI resource endpoints.
  """

  ###
  # TODO:
  #  * Determine the future of Ecto.Resource, Ecto.Responders
  #  * Add documentation
  #  * Add delete support
  #  * Consider adding a "records" function
  #  * Consider adding default implimentation of each action.
  #  * Add /relationship support?

  defmacro __using__(opts) do
    plug_module = case opts[:plug] do
      nil      -> Plug.Builder
      :builder -> Plug.Builder
      :router  -> Plug.Router
    end

    quote location: :keep do
      use unquote(plug_module)
      use Relax.Responders
      @behaviour Relax.EctoResource

      # Use each action behavior as appropriate.
      unquote(Relax.EctoResource.use_action_behaviours(opts))

      #TODO: Delete
      import Relax.EctoResource, only: [resource: 2, resource: 1]

      # Fetch and parse JSONAPI params
      plug Plug.Parsers, parsers: [Relax.PlugParser]

      # TODO: Move to Relax.Router.
      # Set parent as param if nested
      plug :nested_relax_resource
      def nested_relax_resource(conn, _opts) do
        case {conn.private[:relax_parent_name], conn.private[:relax_parent_id]} do
          {nil, _}   -> conn
          {_, nil}   -> conn
          {name, id} ->
            new = %{"filter" => Map.put(%{}, name, id)}
            merged = Dict.merge conn.query_params, new, fn(_k, v1, v2) ->
              Dict.merge(v1, v2)
            end
            Map.put(conn, :query_params, merged)
        end
      end

      # Define our plug endpoint that dispatches to each action.
      def relax_resource(conn, _opts) do
        do_resource(conn, conn.method, conn.path_info)
      end

      @before_compile Relax.EctoResource
    end
  end

  def use_action_behaviours(opts) do
    available = [:fetch_all, :fetch_one, :create, :update, :delete]
    allowed = (opts[:only] || available -- (opts[:except] || available)) # last available should be empty list

    quote bind_quoted: [allowed: allowed] do
      if Enum.member?(allowed, :fetch_all), do: use Relax.EctoResource.FetchAll
      if Enum.member?(allowed, :fetch_one), do: use Relax.EctoResource.FetchOne
      if Enum.member?(allowed, :create),    do: use Relax.EctoResource.Create
      if Enum.member?(allowed, :update),    do: use Relax.EctoResource.Update
      #if Enum.member?(allowed, :delete),   do: use Relax.Resource.Delete
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      # If nothing matches, next plug
      def do_resource(conn, _, _), do: conn
    end
  end

  @doc """
  Defines the Module using Ecto.Model to be exposed by this resource.
  """
  defcallback model() :: module

  @doc """
  Defines the Module using Ecto.Repo to be queried by this resource.
  """
  defcallback repo() :: module

  @doc """
  Defines the module using JaSerializer to format this resource.
  """
  defcallback serializer() :: module

  defmacro resource(type) do
    #Relax.EctoResource.use_type(type, [])
  end

  defmacro resource(type, opts) do
    #Relax.EctoResource.use_type(type, opts)
  end

  def use_type(:fetch_all, opts) do
    quote do: use(Relax.EctoResource.FetchAll, unquote(opts))
  end

  def use_type(:fetch_one, opts) do
    quote do: use(Relax.EctoResource.FetchOne, unquote(opts))
  end

  def use_type(:create, opts) do
    quote do: use(Relax.EctoResource.Create, unquote(opts))
  end

  def use_type(:update, opts) do
    quote do: use(Relax.EctoResource.Update, unquote(opts))
  end
end
