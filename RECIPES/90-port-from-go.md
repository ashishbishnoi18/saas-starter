# Port a Go service onto the SaasStarter standard

This recipe is written against the `/var/www/mca-data-service` Go codebase
but generalizes to any Go project that (a) talks to an HTTP API, (b)
persists to SQLite or Postgres, (c) runs batch jobs via cron.

## Mapping — Go → Elixir

| Go concept | SaasStarter concept |
|---|---|
| `main.go` per `cmd/*` binary | Oban worker module + Mix task or scheduler |
| `http.Client` with custom retry | `SaasStarter.HTTP` (Req-based wrapper) |
| `*sql.DB` via `github.com/mattn/go-sqlite3` | `SaasStarter.Repo` (Ecto + Postgres) |
| Struct with `db:"..."` tags | `Ecto.Schema` + `changeset/2` |
| `for { ... sleep }` polling loop | Oban scheduled job |
| Shell scripts that call the binary | Oban worker enqueued on a cron plugin |
| Global state (multi-account rotation) | GenServer + ETS, or Oban unique jobs with metadata |
| `context.Context` timeouts | Req option `:receive_timeout`; Oban `:timeout` |

## Concrete port plan for mca-data-service

### Phase 1: replace batch fetchers with Oban workers

Each of `cmd/fetch-all`, `cmd/fetch-directors`, `cmd/fetch-llps`,
`cmd/backfill-normalized` becomes:

- An **Oban worker** module that processes one identifier at a time
- A **producer** (cron or Mix task) that enqueues work based on a
  "pending" query against the Postgres tables
- A **context module** that owns the API call and the normalization
  (previously `internal/elixir/*` + `internal/normalize/*`)

Example — `fetch-all` becomes:

```elixir
# lib/saas_starter/mca/upscrape_client.ex  (was internal/elixir)
defmodule SaasStarter.MCA.UpscrapeClient do
  def company_get(cin) do
    SaasStarter.HTTP.post(
      "#{base_url()}/execute",
      %{capability: "mca.company.get", identifier: cin},
      headers: auth_headers()
    )
  end
end

# lib/saas_starter/mca/normalize.ex  (was internal/normalize)
defmodule SaasStarter.MCA.Normalize do
  def company_response(cin, raw_json) do
    # same logic as the Go function, now in Ecto.Multi
  end
end

# lib/saas_starter/workers/fetch_company_worker.ex  (was cmd/fetch-all)
defmodule SaasStarter.Workers.FetchCompanyWorker do
  use Oban.Worker, queue: :mca_fetch, max_attempts: 3

  @impl true
  def perform(%Oban.Job{args: %{"cin" => cin}}) do
    with {:ok, %{body: body}} <- SaasStarter.MCA.UpscrapeClient.company_get(cin),
         {:ok, _} <- SaasStarter.MCA.Normalize.company_response(cin, body) do
      :ok
    end
  end
end
```

A separate scheduled worker fills the queue:

```elixir
defmodule SaasStarter.Workers.FillFetchQueue do
  use Oban.Worker, queue: :scheduler

  @impl true
  def perform(_job) do
    SaasStarter.MCA.Companies.list_pending(limit: 200)
    |> Enum.each(fn %{cin: cin} ->
      %{cin: cin}
      |> SaasStarter.Workers.FetchCompanyWorker.new()
      |> Oban.insert()
    end)
    :ok
  end
end
```

### Phase 2: migrate data from SQLite to Postgres

`mca-data/companies.db` (1.7 GB SQLite) → Postgres. Two approaches:

1. **pgloader** — one command:
   ```bash
   pgloader \
     --with "drop indexes, preserve index names" \
     sqlite:///var/www/mca-data-service/mca-data/companies.db \
     postgresql://mca@localhost/saas_starter_dev
   ```
   Hits ~50k rows/s on a modest box. Do this in a staging DB first, run
   `mix ecto.migrations` to add Ecto-managed indexes, verify row counts
   against the source.

2. **Ecto migration + streaming export** — write a one-off Mix task that
   reads from SQLite (via `exqlite` driver) and writes to Postgres in
   batches. Slower, but lets you transform column types on the way in.

### Phase 3: swap schemas

For each SQLite table, write the Ecto schema. Key conversions:

- SQLite `TEXT` dates → Postgres `DATE` or `TIMESTAMPTZ` where appropriate
- SQLite `TEXT` JSON blobs → Postgres `JSONB`
- SQLite `INTEGER` booleans → Postgres `BOOLEAN`
- Add `pg_trgm` GIN index on `companies.company_name` for fuzzy search
  (the Go code had no search; this is a gain for the Phoenix LiveView UI)

### Phase 4: wire the LiveView UI

The Go code had no UI. On the Phoenix side:

- `/app/search` — LiveView with a single search field hitting `pg_trgm`
  on `companies.company_name`
- `/app/companies/:cin` — detail LiveView pulling from `company_full_data`
  JSONB
- `/api/v1/companies/:cin` — optional JSON API for programmatic access
  (gated by API keys if billing is activated)

### Phase 5: decommission the Go binaries

- Mark Go binaries as deprecated in `knowledge.db` (insight +
  changelog row)
- Point crons at the new Oban scheduled jobs
- Keep the Go repo around for 1–2 months as a rollback target
- Delete `mca-data/companies.db` only after Postgres has passed a full
  daily cycle

## Hard rules during the port

- **Preserve raw JSON.** Every row in `company_full_data` / etc.
  keeps its byte-identical raw_json. Never drop data during migration.
- **One Oban worker per verb.** Don't fan a worker out to handle multiple
  capabilities — split so retries and metrics are clean.
- **TLS fingerprinting stays on the scraper side.** The `mca-scraper` Go
  module on `staging.upscrape.com` is the thing that must use Chrome 133
  PSK TLS to pass Akamai. The SaasStarter app just calls the Elixir
  upstream `/execute` — TLS there is a regular HTTPS client.
