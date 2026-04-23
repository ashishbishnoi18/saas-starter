# STACK.md — canonical stack

The decided stack for every project forked from this starter. AI agents:
treat this file as binding. If you think something here should change,
open a discussion with the human — don't silently swap an item.

| Layer | Choice | Notes |
|---|---|---|
| Application DB | **Local Postgres** | One Ecto repo (`SaasStarter.Repo`). Dev connects via Unix socket; prod via `DATABASE_URL`. |
| Language / framework | **Elixir + Phoenix LiveView** | Phoenix 1.8.5, LiveView 1.1.28, Elixir 1.19.5 / OTP 27. |
| Knowledge base | **SQLite `knowledge.db`** | Created by `./kb-init`. See `AGENT.md` for the read/write protocol. The app does NOT open it at runtime. |
| Payments | **Stripe** via `stripity_stripe` | Activation recipe: `RECIPES/31-add-stripe-billing.md`. `SaasStarter.Billing` is the only call path. |
| Authentication | **Google OAuth + magic link** | `phx.gen.auth` provides magic link; `ueberauth_google` provides OAuth. Password login is intentionally removed. |
| Logging / metrics | **`:telemetry`** | Phoenix ships handlers; our `SaasStarter.Events.TelemetryHandler` routes product events to the durable `product_events` table. |
| Session recording | **Phoenix Replay** | Ecto storage, `SaasStarter.ReplaySanitizer` scrubs PII. Viewer UI is admin-gated (future). |
| Frontend tests | **`Phoenix.LiveViewTest`** | One test file per LiveView. Assert on stable DOM IDs, never raw HTML. |
| Hosting | **Hetzner VPS** | Ubuntu 24.04. Deploy via mix release + systemd. (Recipe: future.) |
| Admin panel access | **Tailscale + email allowlist + Google OAuth** | Not publicly routed. Plug-based gate enforces Tailscale IP range + `@config :admin_emails`. Only common gate primitives live in the starter — actual admin pages are app-specific. |
| Backup | **Backblaze B2** | `pg_dump` → B2 via `rclone` or `restic`, daily cron. Reusable script, not app-specific logic. |
| CDN / media storage | **Cloudflare** | R2 for object storage (S3-compatible API), Cloudflare in front as CDN. `SaasStarter.Storage` wrapper covers upload/signed-URL patterns. |
| SMTP | **Amazon SES** | Via SES SMTP endpoints, configured through Swoosh's SMTP adapter. Credentials in env vars. |
| Version control | **GitHub** | `gh` CLI for repo operations. AI agent commits automatically after each cohesive change (one commit per logical unit). |

## What the starter writes vs what each app writes

**Starter ships** (cross-app primitives):

- Google OAuth + magic-link auth scaffolding
- Stripe billing behaviour + stub impl + activation recipe
- Telemetry handler pattern + `product_events` table
- Phoenix Replay config + sanitizer
- LiveView test patterns
- Admin gate plug (Tailscale + allowlist), with an empty
  `live_session :admin` ready to hang pages off — **not** any actual
  admin pages
- Generic storage/CDN wrapper, backup script, deploy skeleton

**Starter does NOT ship** (app-specific):

- Actual admin dashboard pages, feature flags UI, customer-support UI
- Any domain model (`posts`, `products`, `orders`, etc.)
- App-specific LiveViews beyond home / login / dashboard placeholders
- Business logic, pricing tiers, product catalogs

The rule: if it varies per-app, it lives in the app. If it's "every SaaS
needs this, configured the same way," it lives in the starter.

## Deferred until explicitly requested

- Oban (background jobs) — `RECIPES/30-add-oban.md` when needed
- Hammer (rate limiting)
- Wallaby (real-browser tests)
- Sentry / AppSignal (error tracking)
- OpenTelemetry exporter
- Feature flags (`fun_with_flags`)
- Multi-tenancy (orgs/memberships)
