ExUnit.start()

defmodule Forge do
  use Blacksmith

  register :author,
    type:  :map,
    id:    Sequence.next(:author_id),
    name:  Faker.Name.first_name,
    email: Faker.Internet.email

  register :post,
    type:      :map,
    id:        Sequence.next(:post_id),
    title:     Faker.Lorem.sentence,
    body:      Faker.Lorem.paragraph,
    author:    Forge.author,
    published: false

  register :comment,
    type: :map,
    id:   Sequence.next(:comment_id),
    body: Faker.Lorem.paragraph
end
