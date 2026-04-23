# SaasStarter

Phoenix 1.8 + LiveView SaaS template. Designed to be cloned, renamed, and
extended by AI coding sessions (Claude, Cursor, etc.) without them needing
to re-derive conventions.

## What's in v0.1

- **Stack**: Phoenix 1.8.5, LiveView 1.1.28, Ecto + Postgres 16, Tailwind 4
- **Auth**: Google OAuth (Ueberauth) + magic-link email login
  *(password flow was removed — see RECIPES to reinstate)*
- **Pages**: `/` (public), `/users/log-in`, `/dashboard` (auth-gated)
- **Analytics**: `:telemetry` → `product_events` table (SQL funnels) +
  Phoenix Replay (LiveView session recording, Ecto-backed)
- **Email**: Swoosh + SMTP (via gen_smtp) for prod; Local mailbox in dev
- **Stripe**: `stripity_stripe` declared as dep; not wired — see
  `RECIPES/31-add-stripe-billing.md`
- **Knowledge base**: SQLite `knowledge.db` for AI-agent onboarding
  (see `AGENT.md`)

## Quickstart

Prerequisites: **Elixir 1.19+**, **Erlang/OTP 27+**, **Postgres 16+**.

```bash
# 1. Clone, rename. See RECIPES/00-clone-and-rename.md for the full procedure.
git clone <this-repo> my_app && cd my_app

# 2. Install deps + prepare db.
mix setup

# 3. Run the app.
mix phx.server
#   → http://localhost:4000
```

## Environment variables

| Var | Purpose | When required |
|---|---|---|
| `DATABASE_URL` | Postgres connection | prod |
| `SECRET_KEY_BASE` | cookie signing | prod |
| `GOOGLE_CLIENT_ID` | Google OAuth | any env with Google login |
| `GOOGLE_CLIENT_SECRET` | Google OAuth | any env with Google login |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | magic-link email | prod |
| `FROM_EMAIL` | `From:` header | always (defaults to `no-reply@localhost`) |

Dev skips Google + SMTP by default — magic-link emails appear in
`/dev/mailbox`. Add `GOOGLE_CLIENT_*` vars to your shell to test OAuth.

## Reading the repo (for humans and AI)

Read these in order:

1. `STACK.md` — the canonical stack declaration (DB, auth, hosting, etc.)
2. `AGENTS.md` — Phoenix/Elixir coding conventions (ships with Phoenix 1.8)
3. `AGENT.md` — knowledge-base protocol for this repo
4. `CONVENTIONS.md` — project-specific hard rules and decisions
5. `RECIPES/*.md` — task-shaped how-to guides

## Running tests

```bash
mix test
```

CI runs `mix format --check-formatted && mix test --warnings-as-errors`.

## Knowledge base

`knowledge.db` is a SQLite file with 10 tables documenting components,
dependencies, insights, etc. It's metadata for AI agents — the app never
reads it at runtime. Run `./kb-init` once to create it; query via the
`sqlite3` CLI.

## Layout

```
lib/saas_starter/                  contexts
  accounts.ex                      magic-link + OAuth user mgmt
  accounts/user.ex
  events.ex                        product_events (track/3)
  events/telemetry_handler.ex      :telemetry → Events.track
  billing.ex                       stub behaviour for future Stripe
  http.ex                          Req wrapper with telemetry
  replay_sanitizer.ex              PII scrubber for Phoenix Replay

lib/saas_starter_web/
  router.ex                        /, /dashboard, /users/*, /auth/*
  controllers/oauth_controller.ex  Ueberauth callback
  live/
    home_live.ex                   public landing
    dashboard_live.ex              auth-gated landing
    user_live/login.ex             Google + magic-link form

test/                              one file per module above
priv/repo/migrations/              users, users_tokens, product_events,
                                   phoenix_replay_recordings, google_sub
```

## License

MIT.
