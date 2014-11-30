ExUnit.start()

defmodule Sequence do
  @moduledoc """
  Manages a sequence of number that are retreived and updated atomically.

  Used to generate ids without requiring a database.
  """
  def start, do: Agent.start(fn() -> 1 end, name: __MODULE__)
  def next_id do
    Agent.get_and_update __MODULE__, fn(id) ->
      {id, id + 1}
    end
  end
end

Sequence.start()

defmodule Forge do
  use Blacksmith

  register :author,
    type:  :map,
    id:    Sequence.next_id,
    name:  Faker.Name.first_name,
    email: Faker.Internet.email

  register :post,
    type:      :map,
    id:        Sequence.next_id,
    title:     Faker.Lorem.sentence,
    body:      Faker.Lorem.paragraph,
    author:    Forge.author,
    published: false

  register :comment,
    type: :map,
    id:   Sequence.next_id,
    body: Faker.Lorem.paragraph
end
