defmodule Relax.Resource do
  use Behaviour

  @moduledoc """
  A behaviour to help build JSONAPI resource endpoints.
  """

  @doc """
  Defines the Module using Ecto.Model to be exposed by this resource.
  """
  defcallback model() :: module

  @doc """
  Defines the Module using Ecto.Repo to be queried by this resource.
  """
  defcallback repo() :: module

  @doc false
  defmacro __using__(opts) do
    plug_module = case opts[:plug] do
      nil      -> Plug.Builder
      :builder -> Plug.Builder
      :router  -> Plug.Router
    end

    quote location: :keep do
      use unquote(plug_module)
      use Relax.Responders
      @behaviour Relax.Resource

      # Use each action behavior as appropriate.
      unquote(Relax.Resource.use_action_behaviours(opts))

      # Fetch and parse JSONAPI params
      plug Plug.Parsers, parsers: [Relax.PlugParser]
      plug Relax.Resource.Nested

      # Define plug endpoint that dispatches to each action behavior.
      def resource(conn, _opts) do
        do_resource(conn, conn.method, conn.path_info)
      end

      # Define plug endpoint that 404s and returns not found
      def not_found(conn, opts) do
        Relax.NotFound.call(conn, Dict.merge(opts, type: :resource))
      end

      unquote(Relax.Resource.default_repo(opts))
      unquote(Relax.Resource.default_model(opts))

      @before_compile Relax.Resource
    end
  end

  @doc false
  def use_action_behaviours(opts) do
    available = [:fetch_all, :fetch_one, :create, :update, :delete]
    allowed = (opts[:only] || available -- (opts[:except] || []))

    quote bind_quoted: [allowed: allowed] do
      if :fetch_all in allowed, do: use Relax.Resource.FetchAll
      if :fetch_one in allowed, do: use Relax.Resource.FetchOne
      if :create in allowed,    do: use Relax.Resource.Create
      if :update in allowed,    do: use Relax.Resource.Update
      if :delete in allowed,    do: use Relax.Resource.Delete
    end
  end

  @doc false
  def default_repo(opts) do
    if opts[:ecto] == false do
      quote do
        def repo, do: :none
      end
    else
      quote do
        if Application.get_env(:relax, :repo) do
          def repo, do: Application.get_env(:relax, :repo)
          defoverridable [repo: 0]
        end
      end
    end
  end

  @doc false
  def default_model(opts) do
    if opts[:ecto] == false do
      quote do
        def model, do: :none
      end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      # If nothing matches, next plug
      def do_resource(conn, _, _), do: conn
    end
  end
end
