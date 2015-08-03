defmodule Relax.Resource do
  use Behaviour

  @moduledoc """
  Provides functionality and defines a behaviour to help build jsonapi.org
  resource endpoints.

  ## Using

  When used, `Relax.Resource` works as an parent module that adds
  common functionality and behaviours and plugs to your module.

  ### Submodules

  When using the module you can pass either an `only` or a `except` option to
  determine what "actions" are available on the resource. By default all
  actions are included.

      use Relax.Resource, except: [:delete]

      use Relax.Resource, only: [:fetch_all, :fetch_one]

  Each included action adds another use statement:

  * `fetch_all` - `use Relax.Resource.FetchAll`
  * `fetch_one` - `use Relax.Resource.FetchOne`
  * `create` - `use Relax.Resource.Create`
  * `update` - `use Relax.Resource.Update`
  * `delete` - `use Relax.Resource.Delete`

  Please see each action's documentation for usage details.

  ### Provided Plugs

  Relax.Resource provides 2 plug functions, `resource` and `not found`.

  * `plug :resource` - Required to dispatch requests to the appropriate action.
  * `plug :not_found` - Optionally returns a 404 for all un-halted conns.

  Example:

      plug :resource
      plug :not_found

  ### Plug.Builder vs Plug.Router

  By default `use Relax.Resource` will also `use Plug.Builder`, however if
  you wish to capture non-standard routes you can pass the `plug: :router`
  option to the use statement and use Plug.Router along side your normal
  resource routes.

      defmodule MyResource do
        use Relax.Resource, plug: :router

        plug :resource
        plug :match
        plug :dispatch

        post ":id/activate" do
          # Work with conn and id directly
        end
      end


  ## Behaviour

  This module also defines a behaviour defining the callbacks needed by all
  action types. The behaviour is added when you use this module.

  """

  @doc """
  Defines the model (struct) this resource is exposes.

  This is typically a module using Ecto.Model, but may be any struct. Example:

      def model, do: MyApp.Models.Post

  """
  defcallback model() :: module

  @doc """
  Defines the module using Ecto.Repo to be queried by this resource.

  This may be defined in each resource, but by default the `:relax` 
  application `repo` config value is used.

  Per resource example:

      def repo, do: MyApp.Repo

  Config example (config.exs):

      config :relax,
        repo: MyApp.Repo

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
