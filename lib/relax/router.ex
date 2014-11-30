defmodule Relax.Router do

  defmacro __using__(_) do
    quote do
      import Relax.Router
      use Plug.Router
    end
  end

  defmacro version(version, do: block) do
    quote do
      @version Atom.to_string(unquote(version))
      @nested_in nil
      unquote(block)
      @version nil
    end
  end

  defmacro resource(name, module) do
    forward_resource(name, module)
  end

  defmacro resource(name, module, do: block) do
    forward_resource(name, module, block)
  end

  # Generate match to forward /:vs/:name to Module
  defp root_forward(name, target) do
    quote do
      defp do_match(_mthd, [@version, unquote(name) | glob]) do
        fn(conn) ->
          opts = unquote(target).init([])
          Plug.Router.Utils.forward(conn, glob, unquote(target), opts)
        end
      end
    end
  end

  # Generate match to forward /:vs/:parent_name/:parent_id/:name to Module
  defp nested_forward(name, target) do
    quote do
      defp do_match(_mthd, [@version, @nested_in, parent_id, unquote(name) | glob]) do
        fn(conn) ->
          opts = unquote(target).init([])
          conn
          |> Plug.Conn.put_private(:relax_parent_name, @nested_in)
          |> Plug.Conn.put_private(:relax_parent_id,   parent_id)
          |> Plug.Router.Utils.forward(glob, unquote(target), opts)
        end
      end
    end
  end

  # Determine how to forward resource, as nested or top level.
  defp forward_resource(name, target) do
    name = Atom.to_string(name)
    quote do
      case @nested_in do
        nil         -> unquote(root_forward(name, target))
        nested_name -> unquote(nested_forward(name, target))
      end
    end
  end

  # Forward resources and set nested context
  defp forward_resource(name, module, block) do
    quote do
      @nested_in Atom.to_string(unquote(name))
      unquote(block)
      @nested_in nil
      unquote(forward_resource(name, module))
    end
  end
end
