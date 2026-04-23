# CONVENTIONS.md

Hard rules for this codebase. AI sessions: read once before your first edit.
If you think a rule should change, open a discussion — don't silently break it.

Phoenix's shipped `AGENTS.md` covers Elixir and LiveView style. This file
covers project-specific decisions that aren't framework-level.

## Architecture

- **One OTP app** (`saas_starter`). No umbrella in v0.1. Revisit only if
  we need to isolate a concern (e.g. long-running background compute).
- **Contexts live under `lib/saas_starter/`**, web code under
  `lib/saas_starter_web/`. No module crosses the `_web` boundary in either
  direction except through the public context API.
- **One module per file.** Never nest `defmodule` inside another — Phoenix
  `AGENTS.md` makes this a hard rule; it causes cyclic compilation errors.

## HTTP

- **All outbound HTTP goes through `SaasStarter.HTTP`** (Req-based wrapper
  with telemetry). Direct `Req`, `HTTPoison`, `Tesla`, or `:httpc` calls
  are forbidden except where a transitive dependency (e.g. Ueberauth) owns
  them internally.

## Analytics

- **Every meaningful user action writes to `product_events`** via
  `SaasStarter.Events.track/3`. Phoenix Replay is additive.
- **Don't insert directly into `product_events`** — always go through the
  `Events` context so validation + telemetry run consistently.

## Auth

- **Two login surfaces, one session**: Google OAuth and magic link both
  call `SaasStarterWeb.UserAuth.log_in_user/2`. Don't invent a third path.
- **Password login is intentionally removed.** The `hashed_password`
  column stays nullable so a future recipe can re-enable it (see
  `RECIPES/`). Don't delete the column; it's reversibility insurance.

## Billing

- **`SaasStarter.Billing.charge/1` is the only call path.** Implementations
  are swapped via `config :saas_starter, :billing, MyImpl`. Don't call
  `Stripe.*` directly from contexts or LiveViews.

## Privacy

- **PII keys listed in `SaasStarter.ReplaySanitizer` never appear in
  recordings.** If you add a schema field that carries PII, add the key to
  `@extra_sensitive_keys` in that module.
- **Secrets never live in config rows.** `knowledge.db` has a trigger that
  enforces this; in application code, read secrets from `System.get_env/1`
  at runtime in `config/runtime.exs`.

## Testing

- **Every context function has a test.** Same for every LiveView, every
  controller, every non-trivial helper module.
- **LiveView tests assert on element IDs**, never on raw HTML strings.
  Give every meaningful element in a template a stable DOM ID.
- **Use `Req.Test.stub` for HTTP isolation.** Never hit live URLs in tests.
- **Use `async: true` unless a test truly needs shared state.**

## Migrations

- Generate with `mix ecto.gen.migration <snake_case_name>` so timestamps
  follow Phoenix conventions.
- Never edit a committed migration — write a new one.
- Migrations go in `priv/repo/migrations/`.

## Commits

- One concern per commit. The git log is a walkthrough for the next AI.
- Conventional commit messages are fine but not required; clarity matters
  more than prefix.

## Forbidden

| Don't | Do instead |
|---|---|
| Call `Req`/`HTTPoison`/`Tesla` directly | `SaasStarter.HTTP.get/2`, `post/3` |
| Insert into `product_events` directly | `SaasStarter.Events.track/3` |
| Reach for a new HTTP/billing/analytics dep | Check if an existing recipe covers it; if not, discuss first |
| Store a secret in `config.value` | Use `config.storage_location` as a pointer |
| Nest modules in the same file | Split to separate files |
| Test against raw HTML | Use `has_element?/2` with stable IDs |
| Skip CI locally before commit | Run `mix format && mix test` |

## Open questions / deferred decisions

These are intentionally unresolved in v0.1 and will be decided when needed:

- Multi-tenancy (orgs/teams): not in scope until we have a use case
- Background jobs: Oban will be added via `RECIPES/30-add-oban.md`
- Feature flags: `fun_with_flags` when we need a gradual rollout
- Rate limiting: `hammer` once we expose a public API
- Error tracking: Sentry when we deploy to prod
- OpenTelemetry export: when we pick an APM vendor
