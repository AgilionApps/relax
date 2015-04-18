defmodule Relax.Router do

  defmacro __using__(_) do
    quote do
      use Plug.Builder
      import Relax.Router

      # Register attribute in which to store our matches
      Module.register_attribute __MODULE__, :relax_routes, accumulate: true

      @before_compile Relax.Router
    end
  end

  defmacro version(version, do: block) do
    quote do
      @version unquote(version) |> Atom.to_string
      @nested_in nil
      unquote(block)
      @version nil
    end
  end

  defmacro resource(name, module) do
    quote do
      name = unquote(name) |> Atom.to_string
      @relax_routes {@version, name, unquote(module), @nested_in}
    end
  end

  defmacro resource(name, module, do: block) do
    quote do
      name = unquote(name) |> Atom.to_string
      @nested_in name
      unquote(block)
      @nested_in nil
      @relax_route {@version, name, unquote(module), nil}
    end
  end


  defmacro __before_compile__(_env) do
    quote do
      def match_api(conn, _opts) do
        do_match_api(conn, conn.path_info)
      end

      Enum.each @relax_routes, fn({version, name, target, parent}) ->
        @current_target target
        case parent do
          nil ->
            defp do_match_api(conn, [var!(version), var!(name) | glob]) do
              conn
              |> Plug.Router.Utils.forward(glob, @current_target, [])
            end
          parent ->
            defp do_match_api(conn, [var!(version), var!(parent), parent_id, var!(name) | glob]) do
              conn
              |> Plug.Conn.put_private(:relax_parent_name, @nested_in)
              |> Plug.Conn.put_private(:relax_parent_id,   parent_id)
              |> Plug.Router.Utils.forward(glob, @current_target, [])
            end
        end
      end

      # Default case (eg no match)
      defp do_match_api(conn, opts), do: conn
    end
  end
end
