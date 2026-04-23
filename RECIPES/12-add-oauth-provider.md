# Add a second OAuth provider (e.g. GitHub)

Google OAuth is wired in v0.1. Adding GitHub (or any other Ueberauth-
supported provider) is a 4-step change.

## Steps

### 1. Add the strategy dependency

```elixir
# mix.exs deps/0
{:ueberauth_github, "~> 0.8"}
```

`mix deps.get`

### 2. Configure the provider

```elixir
# config/config.exs — extend the existing :ueberauth list
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]},
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")
```

Same `System.get_env/1` pair in `config/runtime.exs` (outside the
`if config_env() != :test do` block if you need them in test, inside
otherwise).

### 3. Add a DB column for the subject id

```bash
mix ecto.gen.migration add_github_sub_to_users
```

```elixir
def change do
  alter table(:users) do
    add :github_sub, :string
  end

  create unique_index(:users, [:github_sub])
end
```

Add `field :github_sub, :string` to `SaasStarter.Accounts.User` and include
it in `oauth_changeset/2`.

### 4. Extend the OAuth controller

In `lib/saas_starter_web/controllers/oauth_controller.ex`, add a callback
clause:

```elixir
def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "github"}) do
  attrs = %{
    email: auth.info.email || github_primary_email(auth),
    github_sub: to_string(auth.uid)
  }

  case Accounts.upsert_user_from_oauth(attrs) do
    {:ok, user} -> UserAuth.log_in_user(conn, user)
    {:error, _} -> redirect_to_login(conn, "Could not sign you in.")
  end
end
```

Extend `Accounts.upsert_user_from_oauth/1` to handle `:github_sub` the same
way it handles `:google_sub` (find by provider-sub → find by email → create
new). The match lookup needs to be provider-aware:

```elixir
def upsert_user_from_oauth(%{email: email, github_sub: sub}), do: ...
```

### 5. Add the button to `login_live.ex`

```elixir
<.link
  id="github-login"
  href={~p"/auth/github"}
  class="btn btn-neutral w-full"
>
  Continue with GitHub
</.link>
```

### 6. Write tests

Mirror `test/saas_starter_web/controllers/oauth_controller_test.exs` — one
test per success path (new user, existing magic-link user with matching
email, returning user with existing github_sub) and one failure path.

## Hard rules

- **Never use provider-returned `uid` types directly** — always
  `to_string(auth.uid)`. GitHub returns integers; Google returns strings.
- **Trust only verified emails**. Google only returns verified emails;
  GitHub sometimes returns the primary email as nil (needs extra scope).
  Read the strategy's docs before trusting `auth.info.email`.
- **Keep the session unified** — every provider callback must call
  `UserAuth.log_in_user/2`. Don't invent a parallel session plug.
