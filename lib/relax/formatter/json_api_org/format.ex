defmodule Relax.Formatter.JsonApiOrg.Format do
  alias Relax.Formatter.JsonApiOrg.LinkedResources
  alias Relax.Serializer.Attributes
  alias Relax.Serializer.Relationships

  defmodule Context do
    defstruct model: nil, serializer: nil, conn: nil, meta: %{}
  end

  @doc """
  Returns the jsonapi.org formatted representation of the map/struct as defined
  by the serializer.
  """
  def format(model, serializer, conn, meta) do
    context = %Context{
      model: model, serializer: serializer, conn: conn, meta: meta
    }

    %{}
    |> add_primary_resource(context)
    |> LinkedResources.add(context)
    |> add_meta(context)
    |> Relax.ConvertKeys.camelize
  end

  # Set proper key to the primary resource
  defp add_primary_resource(results, context) do
    formatted = format_resource(context.serializer, context.model, context.conn)
    Map.put(results, context.serializer.__key, formatted)
  end

  # If resource is a list, map over it.
  def format_resource(serializer, models, conn) when is_list(models) do
    Enum.map models, &format_resource(serializer, &1, conn)
  end

  # Get attributes and add nested relationships as needed.
  def format_resource(serializer, model, conn) when is_map(model) do
    atts =      Attributes.get(serializer, model, conn)
    case Relationships.nested(serializer, model, conn) do
      relations when map_size(relations) === 0 -> atts
      relations                                -> Map.put(atts, :links, relations)
    end
  end

  # Adds meta key with meta data if present.
  defp add_meta(results, %Context{meta: meta}) do
    case meta do
      nil                          -> results
      meta when map_size(meta) > 0 -> Map.put(results, "meta", meta)
      _                            -> results
    end
  end
end
