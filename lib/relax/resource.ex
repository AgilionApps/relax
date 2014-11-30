defmodule Relax.Resource do
  @moduledoc """
   TODO: Doc this.
  """

  defmacro __using__(opts) do
    quote do
      use Plug.Router
      use Relax.Responders
      use Relax.Params

      plug Plug.Parsers, parsers: [Relax.PlugParser]
      plug Relax.Resource.Nested

      opts = unquote(opts)
      @actions [:find_all, :find_many, :find_one, :create, :update, :delete]
      @allowed (opts[:only] || @actions -- (opts[:except] || []))

      unquote(Relax.Resource.use_action_behaviours)
    end
  end

  def use_action_behaviours do
    quote do
      if Enum.member?(@allowed, :find_all), do: use Relax.Resource.FindAll
      if Enum.member?(@allowed, :create),   do: use Relax.Resource.Create
      if Enum.member?(@allowed, :update),   do: use Relax.Resource.Update
      if Enum.member?(@allowed, :delete),   do: use Relax.Resource.Delete
      if Enum.member?(@allowed, :find_many) || Enum.member?(@allowed, :find_one) do
        use Relax.Resource.FindN
      end
    end
  end
end
