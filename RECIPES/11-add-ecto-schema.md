# Add an Ecto schema + context function

## Steps

1. `mix ecto.gen.migration create_<plural>` — underscore_snake_case names
   enforce Phoenix timestamp conventions.
2. Write the migration (`create table`, indexes, constraints).
3. Write the schema at `lib/saas_starter/<context>/<singular>.ex`.
4. Add a context function to `lib/saas_starter/<context>.ex`.
5. Write the test at `test/saas_starter/<context>_test.exs`.

## Example: add a `:posts` table owned by `Content` context

### Migration

```elixir
# priv/repo/migrations/<timestamp>_create_posts.exs
defmodule SaasStarter.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:user_id])
  end
end
```

### Schema

```elixir
# lib/saas_starter/content/post.ex
defmodule SaasStarter.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset
  alias SaasStarter.Accounts.User

  schema "posts" do
    field :title, :string
    field :body, :string       # Ecto uses :string even for :text columns
    belongs_to :user, User
    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body])
    |> validate_required([:title, :body])
    |> validate_length(:title, max: 200)
  end
end
```

**Do not** list `user_id` in `cast/3`. Set it explicitly when creating the
struct — otherwise you're open to mass-assignment of foreign keys.

### Context function

```elixir
# lib/saas_starter/content.ex
defmodule SaasStarter.Content do
  alias SaasStarter.Repo
  alias SaasStarter.Content.Post
  alias SaasStarter.Accounts.User

  def create_post(%User{} = user, attrs) do
    %Post{user_id: user.id}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end
end
```

### Test

```elixir
# test/saas_starter/content_test.exs
defmodule SaasStarter.ContentTest do
  use SaasStarter.DataCase, async: true
  import SaasStarter.AccountsFixtures

  alias SaasStarter.Content

  test "create_post/2 persists a post owned by the user" do
    user = user_fixture()
    assert {:ok, post} = Content.create_post(user, %{title: "hi", body: "there"})
    assert post.user_id == user.id
  end

  test "rejects missing title" do
    user = user_fixture()
    assert {:error, cs} = Content.create_post(user, %{body: "x"})
    assert %{title: [_ | _]} = errors_on(cs)
  end
end
```

## Pitfalls

- **`Ecto.Changeset.validate_number/2` has no `:allow_nil`.** Validations
  only run when a change exists for the field; nil is already handled.
- **Access changeset fields with `Ecto.Changeset.get_field/2`**, never
  `changeset[:field]` (structs don't implement Access).
- **Always preload associations** you'll render in templates, or you'll
  hit an N+1.
