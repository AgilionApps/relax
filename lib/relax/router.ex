defmodule Relax.Router do

  @moduledoc """
  A DSL for defning your route structures.
  """

  @doc false
  defmacro __using__(opts) do
    plug_module = case opts[:plug] do
      nil      -> Plug.Builder
      :builder -> Plug.Builder
      :router  -> Plug.Router
    end

    quote location: :keep do
      use unquote(plug_module)
      import Relax.Router

      def route(conn, _opts) do
        do_relax_route(conn, conn.path_info)
      end

      def not_found(conn, opts) do
        Relax.NotFound.call(conn, Dict.merge(opts, type: :route))
      end
    end
  end

  @doc """

  """
  defmacro version(version, do: block) do
    quote do
      @version Atom.to_string(unquote(version))
      @nested_in nil
      unquote(block)
      @version nil
    end
  end

  @doc """

  """
  defmacro resource(name, module) do
    forward_resource(name, module)
  end

  @doc """

  """
  defmacro resource(name, module, do: block) do
    forward_resource(name, module, block)
  end

  # Generate match to forward /:vs/:name to Module
  defp root_forward(name, target) do
    quote do
      def do_relax_route(conn, [@version, unquote(name) | glob]) do
        conn = Map.put(conn, :path_info, glob)
        apply(unquote(target), :call, [conn, []])
      end
    end
  end

  # Generate match to forward /:vs/:parent_name/:parent_id/:name to Module
  defp nested_forward(name, target) do
    quote do
      def do_relax_route(conn, [@version, @nested_in, parent_id, unquote(name) | glob]) do
        conn = conn
                |> Plug.Conn.put_private(:relax_parent_name, @nested_in)
                |> Plug.Conn.put_private(:relax_parent_id,   parent_id)
                |> Map.put(:path_info, glob)
        apply(unquote(target), :call, [conn, []])
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
