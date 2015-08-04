defmodule Relax.Resource.PermittedParams do
  use Behaviour

  @doc """
  A while list of attributes (as atoms) to be merged to params.

  First argument is either `:create` or `:update`, dependeing on what action is
  being called.

  Examples:

      def permitted_attributes(:create, _conn), do: [:title, :slug, :body]

      def permitted_attributes(_, conn) do
        if conn.assigns[:current_user].admin? do
          [:email, :password, :admin]
        else
          [:email, :password]
        end
      end
  """
  defcallback permitted_attributes(atom, Plug.Conn.t) :: [atom]

  @doc """
  A while list of relations (as atoms) to be merged to params.

  First argument is either `:create` or `:update`, dependeing on what action is
  being called.

  Relationships each have _id added to the end during formatting.

  Example:

      def premitted_relations(:create, _conn), do: [:category, :author]
      def premitted_relations(:update, _conn), do: [:category]

  """
  defcallback permitted_relations(atom, Plug.Conn.t) :: [atom]

  @doc """
  Filters the JSONAPI attributes and relationships based on keyword list
  """
  def filter(%Plug.Conn{params: p}, opts) do
    relationships = Enum.reduce opts[:relations], %{}, fn(r, acc) ->
      key = Atom.to_string(r)
      val = p["data"]["relationships"][key]["data"]["id"]
      Dict.put(acc, key <> "_id", val)
    end

    p["data"]["attributes"]
    |> Dict.take(Enum.map(opts[:attributes], &Atom.to_string/1))
    |> Dict.merge(relationships)
  end
end
