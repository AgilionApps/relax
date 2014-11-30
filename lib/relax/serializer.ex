defmodule Relax.Serializer do
  @moduledoc """
  A DSL to define how a map or struct is serialized.

  Provides a set of macros to define what to serialize. For example:

      defmodule PostSerializer do
        use Relax.Serializer

        path "/v1/posts/:id"

        serialize "posts" do
          attributes [:id, :title, :body, :is_published]
          has_one  :author, field: :author_id, serializer: UserSerializer
          has_many :comments
          has_many :flagged_comments, link: "/v1/posts/:id/flagged_comments"
        end

        def is_published(post, _conn) do
          post.posted_at != nil
        end

        # Returns list of ids to include.
        # Overrides default implementation: `Map.get(post, :comments)`
        def comments(post, _conn) do
          Comments.by_post(post) |> Enum.map(&Map.get(&1, :id))
        end
      end

  A map or struct can then be passed to the serializer to return a the map now
  in the Relax.org format.

      post = %{id: 1, title: "Elixir is Sake", body: "yum", is_published: nil}
      PostSerializer.as_json(post, conn)

  This can then be passed to your JSON encoder of choice for encoding to a
  binary.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      @attributes []
      @relations  []
      @key        nil
      @location   nil

      import Relax.Serializer,          only: [serialize: 2]
      import Relax.Serializer.Location, only: [path: 1]

      @before_compile Relax.Serializer
    end
  end

  @doc """
  Main API to define a serializer.
  """
  defmacro serialize(key, do: block) do
    quote do
      import Relax.Serializer, only: [
        attributes: 1, has_many: 2, has_many: 1, has_one: 2, has_one: 1
      ]

      @key unquote(key)
      unquote(block)
    end
  end

  defmacro attributes(atts) do
    quote bind_quoted: [atts: atts] do
      # Save attributes
      @attributes @attributes ++ atts

      # Define default attribute function, make overridable
      for att <- atts do
        def unquote(att)(model, _conn), do: Map.get(model, unquote(att))
        defoverridable [{att, 2}]
      end
    end
  end

  @doc """

  Adds a serialized relationship. By default expects to include a list of ids
  in the serialized resource. Include the full resource in the output by
  included a serializer option.

  Override the default by defining a function of relation name with arity of 2.

  ## Opts

  * field - The field to call on the model to get a list of ids. Defaults to
            the relation name.
  * serializer - If defined full representation is expected in response. Should
                 be a module name.
  * link - Represent this resource as a link to another resource.

  """
  defmacro has_many(name, opts \\ []) do
    quote bind_quoted: [name: name, opts: opts] do
      @relations [{:has_many, name, opts} | @relations]
      # Define default relation function, make overridable
      def unquote(name)(model, _conn) do
        Map.get(model, (unquote(opts)[:field] || unquote(name)))
      end
      defoverridable [{name, 2}]
    end
  end

  defmacro has_one(name, opts \\ []) do
    #TODO: Dry up setting up relationships.
    quote bind_quoted: [name: name, opts: opts] do
      @relations [{:has_one, name, opts} | @relations]
      # Define default relation function, make overridable
      def unquote(name)(model, _conn) do
        Map.get(model, (unquote(opts)[:field] || unquote(name)))
      end
      defoverridable [{name, 2}]
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def __attributes, do: @attributes
      def __key,        do: @key
      def __relations,  do: @relations
      def __location,   do: @location

      def as_json(model, conn, meta) do
        Relax.Formatter.JsonApiOrg.format(model, __MODULE__, conn, meta)
      end

      def location(model) do
        Relax.Serializer.Location.generate(model, __location)
      end
    end
  end
end
