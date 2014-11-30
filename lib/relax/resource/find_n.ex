defmodule Relax.Resource.FindN do
  use Behaviour

  @doc "Find one resource, sets conn status and body"
  defcallback find_one(conn :: Plug.Conn.t, id :: binary) :: Plug.Conn.t

  @doc "Find many resource, sets conn status and body"
  defcallback find_many(conn :: Plug.Conn.t, ids :: [binary]) :: Plug.Conn.t

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Resource.FindN

      def find_one(conn, _id),  do: conn
      def find_many(conn, _id), do: conn
      defoverridable [find_one: 2, find_many: 2]

      get "/:id_or_ids" do
        ids        = var!(id_or_ids) |> String.split(",")
        find_many? = Enum.member?(@allowed, :find_many)
        find_one?  = Enum.member?(@allowed, :find_one)
        case {find_many?, find_one?, ids} do
          {_, true, [id]} -> find_one(var!(conn), id)
          {true, _, ids}  -> find_many(var!(conn), ids)
        end
      end
    end
  end
end
