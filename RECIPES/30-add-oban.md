# Add Oban (background jobs)

Oban is deliberately **not** in v0.1 — the starter has no jobs yet. When
you need background work (sending emails asynchronously, scraping APIs on
a schedule, long-running imports), add it in one pass.

## Steps

### 1. Add the dep

```elixir
# mix.exs
{:oban, "~> 2.21"}
```

`mix deps.get`

### 2. Migration

```bash
mix ecto.gen.migration add_oban_jobs_table
```

```elixir
def up, do: Oban.Migration.up()
def down, do: Oban.Migration.down()
```

### 3. Config

```elixir
# config/config.exs
config :saas_starter, Oban,
  repo: SaasStarter.Repo,
  queues: [default: 10, mailers: 5]

# config/test.exs — use inline mode so tests run synchronously
config :saas_starter, Oban, testing: :inline
```

### 4. Supervision

```elixir
# lib/saas_starter/application.ex
children = [
  ...existing children...,
  {Oban, Application.fetch_env!(:saas_starter, Oban)}
]
```

### 5. First worker

```elixir
# lib/saas_starter/workers/email_worker.ex
defmodule SaasStarter.Workers.EmailWorker do
  use Oban.Worker, queue: :mailers, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "kind" => kind}}) do
    user = SaasStarter.Accounts.get_user!(user_id)
    SaasStarter.Mailer.deliver_email(user, kind)
  end
end
```

### 6. Test

```elixir
# test/saas_starter/workers/email_worker_test.exs
defmodule SaasStarter.Workers.EmailWorkerTest do
  use SaasStarter.DataCase, async: true
  use Oban.Testing, repo: SaasStarter.Repo

  import SaasStarter.AccountsFixtures

  test "sends email" do
    user = user_fixture()

    assert {:ok, _} =
             perform_job(SaasStarter.Workers.EmailWorker,
               %{user_id: user.id, kind: "welcome"})
  end

  test "enqueuing inserts a job row" do
    assert {:ok, _job} =
             %{user_id: 1, kind: "welcome"}
             |> SaasStarter.Workers.EmailWorker.new()
             |> Oban.insert()

    assert_enqueued worker: SaasStarter.Workers.EmailWorker, args: %{user_id: 1, kind: "welcome"}
  end
end
```

## Cron

For scheduled jobs, use Oban Pro's Cron plugin, or for open source:

```elixir
config :saas_starter, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", SaasStarter.Workers.HourlyWorker}
     ]}
  ]
```

## Hard rules

- Every worker has a test. Use `Oban.Testing` — never hit the real Oban
  tables in tests; `testing: :inline` runs `perform/1` synchronously.
- Workers are **the** async primitive. Don't spawn raw `Task`s for work
  that must survive a process crash; use an Oban job with `max_attempts`.
- If a job talks to an external API, wrap the call in `SaasStarter.HTTP`
  (not raw Req) so retries are telemetry-visible.
