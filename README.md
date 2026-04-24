# SaasStarter

> A Phoenix 1.8 + LiveView SaaS template, built to be driven by AI coding
> agents (Claude Code, Cursor, Aider, etc.) without them having to re-derive
> conventions each session.

Clone this repo, hand the prompt in [How to use](#how-to-use) to an AI
session, and you skip weeks of stack bikeshedding. The template ships
the boring, repeatable parts (auth, billing scaffold, observability,
tests, deploy scripts). Your AI writes only the parts that are specific
to your product.

---

## Table of contents

- [Overview](#overview)
- [Who this is for](#who-this-is-for)
- [Will this build my whole SaaS automatically?](#will-this-build-my-whole-saas-automatically)
- [What's inside](#whats-inside)
  - [Ready out of the box](#1-ready-out-of-the-box-no-code-to-write)
  - [Activate when you need them](#2-activate-when-you-need-them-small-code-or-config-change)
  - [You (or the AI) write](#3-you-or-the-ai-write-every-app-is-different)
  - [External accounts + infra](#4-external-accounts--infrastructure-you-sign-up-ai-cant)
- [How to use](#how-to-use)
  - [Option A — start a brand-new SaaS](#option-a--start-a-brand-new-saas)
  - [Option B — port an existing codebase](#option-b--port-an-existing-codebase-onto-this-standard)
- [The stack](#the-stack)
- [Repository tour](#repository-tour)
- [Environment variables](#environment-variables)
- [Knowledge base (knowledge.db)](#knowledge-base-knowledgedb)
- [FAQ](#faq)
- [License](#license)

---

## Overview

Every SaaS needs the same plumbing: auth, billing, email, analytics,
tests, deployment, an admin surface, backups, a CDN. This repo is a
complete, runnable Phoenix 1.8 app with that plumbing already wired,
plus a set of **conventions** (files named `STACK.md`, `AGENT.md`,
`CONVENTIONS.md`, `RECIPES/*.md`) that teach an AI agent how to extend
the codebase without breaking your standards.

You use it by cloning into a new project, renaming it, and giving your
AI agent one prompt that points at the right docs. The agent reads
those docs, understands the stack, and builds your product-specific
code on top.

## Who this is for

- **Indie devs and small teams** who want to ship faster by letting AI
  write most of the code.
- **Anyone building multiple SaaS apps** who's tired of making the same
  stack choices over and over.
- **Novices** who know what they want to build but not how to wire up
  auth/billing/hosting — the AI handles all of it; you handle the
  business idea.

You need: a working internet connection, a GitHub account, and willingness
to run `git clone` + paste a prompt. That's it.

## Will this build my whole SaaS automatically?

**No — and it shouldn't.** Here's the honest split:

1. **Ready out of the box** — runs immediately, nothing to do.
   (auth, magic links, session recording, telemetry, three example pages)
2. **Activate when needed** — dep is declared, recipe tells the AI
   exactly how to wire it. (Stripe billing, background jobs, OAuth with
   other providers)
3. **Your AI writes** — the unique parts of your product that nobody
   else has. (domain models, custom LiveViews, admin pages, business
   rules)
4. **External accounts + infrastructure** — only a human can do these,
   no AI agent can sign up for your Stripe account or point your DNS.

The prompt in [How to use](#how-to-use) makes this split visible to the
AI — it will know what's done, what to wire up, what to build, and what
to ask you about.

## What's inside

### 1. Ready out of the box (no code to write)

You get these for free the moment you clone and run `mix setup`:

| Component | What it does |
|---|---|
| **Phoenix 1.8 + LiveView 1.1** | The whole web framework, configured |
| **Postgres + Ecto** | DB layer with migrations |
| **Google OAuth sign-in** | "Continue with Google" button, no password |
| **Magic-link email login** | Send a link to the user's email; clicking it logs them in |
| **Three starter pages** | `/` (public home), `/users/log-in`, `/dashboard` (auth-gated) |
| **Telemetry → `product_events` table** | Every LiveView mount + event becomes a durable SQL-queryable row for funnels and retention analysis |
| **Phoenix Replay** | Server-side session recording with PII scrubbing — watch what users did, without recording their screen |
| **LiveView tests** | Every page has a test. `mix test` is the quality gate |
| **HTTP wrapper with telemetry** | `SaasStarter.HTTP` wraps all outbound HTTP so calls show up in analytics |
| **Admin gate plug** | `SaasStarterWeb.Plugs.AdminGate` — only Tailscale IPs + allowlisted emails can reach `/admin/*` |
| **Object-storage wrapper** | `SaasStarter.Storage` for Cloudflare R2 — `put/delete/presigned_url/public_url` |
| **Billing behaviour** | `SaasStarter.Billing` — swappable stub/live Stripe impl |
| **Backup script** | `scripts/backup.sh` — pg_dump → restic → Backblaze B2, with 7d/4w/12m retention |
| **AI-commit script** | `scripts/ai-commit.sh` — runs format + compile + test before every commit; blocks broken commits |
| **Knowledge base** | `knowledge.db` — SQLite notebook for AI agents to record findings across sessions |
| **CI workflow** | `.github/workflows/ci.yml` — format check, warnings-as-errors compile, test |

### 2. Activate when you need them (small code or config change)

These ship as declared dependencies and documented recipes. The AI
flips them on by following a specific `RECIPES/*.md` file:

| Component | Activation recipe |
|---|---|
| **Stripe billing** (dep present, Live impl + webhook controller shipped, not wired in router) | [`RECIPES/31-add-stripe-billing.md`](RECIPES/31-add-stripe-billing.md) |
| **More OAuth providers** (GitHub, Apple, etc.) | [`RECIPES/12-add-oauth-provider.md`](RECIPES/12-add-oauth-provider.md) |
| **Background jobs** via Oban | [`RECIPES/30-add-oban.md`](RECIPES/30-add-oban.md) |
| **Deploy to Hetzner VPS** | [`RECIPES/40-deploy-to-hetzner.md`](RECIPES/40-deploy-to-hetzner.md) |
| **Automated Backblaze B2 backups** | [`RECIPES/50-backup-b2.md`](RECIPES/50-backup-b2.md) |
| **Amazon SES for email** (domain verification, sandbox exit) | [`RECIPES/60-setup-ses.md`](RECIPES/60-setup-ses.md) |

### 3. You (or the AI) write (every app is different)

The template explicitly does NOT ship these — each app's version is
different:

- **Your product's domain model** — the Ecto schemas and context
  modules for *your* business (posts, orders, campaigns, whatever).
- **Your custom LiveViews** — the pages that make your SaaS what it is
  (search, editor, dashboard widgets, settings).
- **Your admin pages** — the gate plug is shipped, but the actual
  "manage users / see orders / impersonate" pages are up to you.
- **Your pricing tiers + event-handler logic** — the Stripe webhook
  controller dispatches events; *what you do* with
  `checkout.session.completed` is your call.
- **Your marketing / landing copy** — the home page is a skeleton;
  replace with your actual pitch.

The AI prompt in [How to use](#how-to-use) tells the agent which
category each task falls into so it doesn't over-engineer or
under-deliver.

### 4. External accounts + infrastructure (you sign up, AI can't)

The AI can read and configure these, but only a human can set them up.
Decide which you need now and sign up for the rest later:

- **GitHub** — for the repo itself
- **Postgres** — local for dev; hosted (Hetzner/Supabase/etc.) for prod
- **Google Cloud Console** — to get OAuth client ID + secret
- **Amazon SES** — SMTP credentials + domain verification
- **Stripe** — for payments (when you activate billing)
- **Hetzner Cloud** — VPS provider (or substitute: DigitalOcean, Linode, etc.)
- **Cloudflare** — account + R2 bucket + CDN zone (when using file storage)
- **Backblaze B2** — bucket for encrypted backups
- **Tailscale** — free tier for the admin-only VPN

All of these have free tiers that let you start for $0.

---

## How to use

> **Shortcut**: paste [`TEMPLATE.md`](TEMPLATE.md) into your AI agent — it
> contains the full copy-pasteable prompts for both modes below. Or tell
> the agent "follow TEMPLATE.md from this repo" and it'll fetch and
> execute it itself.

Two modes. Pick whichever fits.

### Option A — start a brand-new SaaS

**Step 1.** Fork or push this repo to your own GitHub.
(If you just cloned it, do `git remote set-url origin
git@github.com:YOUR_USERNAME/your-project.git` and push.)

**Step 2.** Open your AI agent of choice (Claude Code, Cursor, Aider,
etc.) in a fresh empty directory.

**Step 3.** Paste this prompt, filling the two `{...}` placeholders:

```text
I'm building a new SaaS called {YOUR_APP_NAME} ({YOUR_APP_MODULE}).

Use my starter template as the foundation:

  Source repo: https://github.com/YOUR_USERNAME/saas-starter
  Branch: main

## Your onboarding procedure

1. Clone the source repo into the current directory (or a subdirectory).
2. Read these files IN ORDER — they're the contract:
   - STACK.md          (the canonical stack, binding)
   - AGENTS.md         (Phoenix/Elixir coding conventions)
   - AGENT.md          (knowledge.db protocol + commit rules)
   - CONVENTIONS.md    (forbidden patterns + decisions)
   - RECIPES/00-clone-and-rename.md  (the rename procedure)
3. Run RECIPES/00-clone-and-rename.md exactly, renaming
   saas_starter → {your_app_name} and SaasStarter → {YourAppModule}.
4. Delete RECIPES/00-clone-and-rename.md and RECIPES/90-port-from-go.md
   (neither applies to a fresh project).
5. Run ./kb-init to refresh knowledge.db.
6. Run `mix setup` and `mix test` — must pass green before any feature
   work. If Postgres isn't reachable, ask me to create the role before
   continuing.
7. Query knowledge.db for any existing facts:
     sqlite3 knowledge.db "SELECT * FROM components"

## Your first feature

{DESCRIBE YOUR FIRST FEATURE HERE — be specific about what the user
should see and do. Example: "Build a landing page that describes the
product as a tool for X, Y, Z. Add a `/pricing` LiveView with three
tiers. Add a dashboard widget that shows 'Welcome, {user.email}' plus
an empty state for the first action they should take."}

## Ground rules

- Use `scripts/ai-commit.sh "<message>"` for every commit — it runs
  format + compile --warnings-as-errors + test as a gate. If the gate
  fails, fix forward.
- One commit per cohesive change.
- After each meaningful change, append to knowledge.db's `changelog`
  table and any relevant `insights`.
- Do NOT modify STACK.md or CONVENTIONS.md without surfacing the change
  to me first.
- If you need an external account (Google OAuth creds, Stripe keys,
  Hetzner VPS, Cloudflare R2 bucket, etc.), stop and tell me what you
  need and why. Don't try to fake it.
- Activation recipes for billing, email provider, deployment, etc. live
  in RECIPES/. Read the relevant one before wiring its component.

Stop and ask me if anything is ambiguous.
```

**Step 4.** The agent will read the docs, rename the project, run the
tests, and start building your feature. When it hits something external
(OAuth keys, Stripe account), it'll tell you what to do.

### Option B — port an existing codebase onto this standard

Pattern is the same, but instead of building a feature, you're
migrating an existing project. The `RECIPES/90-port-from-go.md` file
gives a phase-by-phase migration plan (originally written for a Go
codebase; adapt for your source language).

**Step 1–2.** Same as above.

**Step 3.** Paste this prompt:

```text
I want to port my existing project at {ABSOLUTE_PATH_TO_EXISTING_CODE}
onto my starter template. The target name for the ported project is
{NEW_APP_NAME} / {NewAppModule}.

Source template: https://github.com/YOUR_USERNAME/saas-starter (main)

## Your onboarding procedure

1. Clone the template into this directory as {new-app-name}/.
2. Read (in order):
   - STACK.md
   - AGENTS.md
   - AGENT.md
   - CONVENTIONS.md
   - RECIPES/00-clone-and-rename.md
   - RECIPES/90-port-from-go.md  (the migration guide — adapt for
     {MY_SOURCE_LANGUAGE} if it's not Go)
3. Run the rename procedure. Delete RECIPES/00 after.
   KEEP RECIPES/90 — it's your migration guide.
4. `./kb-init` + `mix setup` + `mix test` (green before continuing).

## Migration plan

Do the port in phases. Stop after each phase and show me a summary
before moving on.

Phase 1 — Scaffold:
  - Clone template, rename, green test suite.
  - Translate the existing data model to Ecto schemas and migrations.
  - DO NOT migrate data yet; migrations should run on an empty DB.

Phase 2 — Data migration dry run:
  - Write a one-off Mix task that copies data from the old DB (or files,
    if no DB) into the new Postgres.
  - Run against a copy, not the live DB. Verify row counts.

Phase 3 — Logic port:
  - Port the existing business logic to Elixir contexts.
  - Every ported function gets a test.
  - Use SaasStarter.HTTP for outbound HTTP (never raw Req/HTTPoison).
  - Use Oban for anything that was a cron job or background worker
    (activate via RECIPES/30-add-oban.md).

Phase 4 — UI:
  - Build the LiveView UI for the customer-facing surface.
  - Mark the old codebase read-only and start pointing traffic at the
    new app gradually.

Phase 5 — Decommission:
  - After two weeks of stable operation, retire the old codebase.
  - Log the retirement in knowledge.db's changelog table.

## Ground rules

- Same as Option A: `scripts/ai-commit.sh` for every commit, one commit
  per cohesive change, knowledge.db updated as you go.
- Preserve raw data. Never drop source data mid-migration; always write
  the imported data to a new table/bucket, verify, then cut over.
- If a port needs a component that isn't in the template yet (Oban,
  Stripe, R2 storage), activate it via the matching RECIPES file —
  don't reinvent.

Stop and ask me between phases.
```

**Step 4.** The agent works phase-by-phase and checks in with you.

---

## The stack

This is what every project forked from this template ships with. Full
detail in [`STACK.md`](STACK.md).

| Layer | Choice | Why this one |
|---|---|---|
| **Language + framework** | Elixir 1.19 + Phoenix 1.8 + LiveView 1.1 | Best-in-class server-rendered reactivity; small JS footprint; first-class testing |
| **Application DB** | Postgres 16 (local or hosted) | Mature, ACID, pg_trgm for search, JSONB when you need flexibility |
| **Knowledge DB** | SQLite `knowledge.db` | File-based agent notebook; no service to run |
| **Frontend tests** | `Phoenix.LiveViewTest` | Same process as the app; no browser needed for 95% of tests |
| **Payments** | Stripe (via `stripity_stripe`) | Industry standard; Checkout offloads PCI scope |
| **Auth** | Google OAuth + magic link (`phx.gen.auth` + `ueberauth_google`) | Passwordless UX; no password-leak blast radius |
| **Logging / metrics** | `:telemetry` → `product_events` | Phoenix-native; SQL-queryable funnels |
| **Session recording** | Phoenix Replay | Server-side; no DOM scraping; privacy-safe |
| **Email (SMTP)** | Amazon SES | Cheap, deliverable, works with any SMTP adapter |
| **Hosting** | Hetzner VPS | ~€4/mo CX22 is enough to start; dedicated IP; EU-based |
| **Admin panel access** | Tailscale + email allowlist + Google OAuth | Not exposed to public internet; zero-config VPN |
| **Backup** | Backblaze B2 via restic | Encrypted, deduplicated, cheap egress |
| **CDN / media storage** | Cloudflare R2 + Cloudflare CDN | Zero egress fees; S3-compatible |
| **Version control** | GitHub + `gh` CLI | Standard; integrates with every AI tool |

## Repository tour

```
saas-starter/
├── README.md            ← you are here
├── STACK.md             ← canonical stack (binding)
├── AGENTS.md            ← Phoenix/Elixir coding rules (ships with Phoenix)
├── AGENT.md             ← knowledge.db protocol for AI sessions
├── CONVENTIONS.md       ← forbidden patterns + decision log
├── RECIPES/             ← task-shaped how-to guides
│   ├── 00-clone-and-rename.md
│   ├── 10-add-liveview-page.md
│   ├── 11-add-ecto-schema.md
│   ├── 12-add-oauth-provider.md
│   ├── 20-add-context-fn.md
│   ├── 30-add-oban.md
│   ├── 31-add-stripe-billing.md
│   ├── 40-deploy-to-hetzner.md
│   ├── 50-backup-b2.md
│   ├── 60-setup-ses.md
│   └── 90-port-from-go.md
│
├── kb-init              ← bash script: initializes knowledge.db
├── knowledge.db         ← SQLite metadata store for AI sessions
│
├── scripts/
│   ├── ai-commit.sh     ← pre-commit gate (format + compile + test)
│   └── backup.sh        ← pg_dump → restic → Backblaze B2
│
├── lib/saas_starter/         ← business-logic contexts
│   ├── accounts.ex           ← users, magic-link, OAuth upsert
│   ├── events.ex             ← product_events.track/3
│   ├── events/telemetry_handler.ex
│   ├── billing.ex            ← behaviour
│   ├── billing/stub.ex       ← default (no-op)
│   ├── billing/live.ex       ← Stripe Checkout impl (not activated)
│   ├── billing/event_handler.ex
│   ├── http.ex               ← Req wrapper with telemetry
│   ├── storage.ex            ← Cloudflare R2 (S3-compatible)
│   └── replay_sanitizer.ex   ← scrubs PII from Phoenix Replay
│
├── lib/saas_starter_web/
│   ├── router.ex
│   ├── plugs/admin_gate.ex   ← Tailscale + email allowlist
│   ├── controllers/
│   │   ├── oauth_controller.ex
│   │   └── stripe_webhook_controller.ex
│   └── live/
│       ├── home_live.ex
│       ├── dashboard_live.ex
│       └── user_live/login.ex
│
├── test/                     ← one file per module
├── priv/repo/migrations/     ← users + tokens + product_events + replay + google_sub
├── config/
│   ├── config.exs
│   ├── dev.exs / test.exs / prod.exs
│   └── runtime.exs           ← env-var reads for prod
├── .github/workflows/ci.yml
└── mix.exs
```

## Environment variables

Set these in your shell (dev) or on your VPS (prod). None are required
for a first `mix setup` + `mix test` run on a default local Postgres.

### Core

| Var | Purpose | When required |
|---|---|---|
| `DATABASE_URL` | Postgres connection string | prod |
| `SECRET_KEY_BASE` | Cookie signing secret | prod (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Canonical hostname (e.g. `app.example.com`) | prod |
| `PHX_SERVER` | Set to `true` to start HTTP listener when using releases | prod |

### Auth

| Var | Purpose | When required |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Google OAuth app | whenever you want Google sign-in |
| `GOOGLE_CLIENT_SECRET` | — same — | — |

### Email (SES or any SMTP provider)

| Var | Purpose | When required |
|---|---|---|
| `SMTP_HOST` | `email-smtp.<region>.amazonaws.com` for SES | prod |
| `SMTP_PORT` | Typically `587` | prod |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | From SES "Create SMTP credentials" | prod |
| `FROM_EMAIL` | `From:` header (e.g. `no-reply@send.example.com`) | always (defaults to `no-reply@localhost`) |

### Admin

| Var | Purpose | When required |
|---|---|---|
| `ADMIN_EMAILS` | Comma-separated list of emails allowed through `AdminGate` | whenever you want `/admin/*` to work |

### Cloudflare R2 (when using `SaasStarter.Storage`)

| Var | Purpose | When required |
|---|---|---|
| `R2_ACCOUNT_ID` | 32-char Cloudflare account id | storage activated |
| `R2_ACCESS_KEY_ID` | R2 S3-compatible access key | — |
| `R2_SECRET_ACCESS_KEY` | R2 S3-compatible secret | — |
| `R2_BUCKET` | Bucket name | — |
| `PUBLIC_CDN_BASE_URL` | e.g. `https://cdn.example.com` | if serving public assets |

### Backups (Backblaze B2)

| Var | Purpose | When required |
|---|---|---|
| `RESTIC_REPOSITORY` | e.g. `b2:mybucket:/saas-prod` | backups running |
| `RESTIC_PASSWORD` | Encryption passphrase (keep safe!) | — |
| `B2_ACCOUNT_ID` / `B2_ACCOUNT_KEY` | B2 application key + secret | — |

### Stripe (when billing is activated)

| Var | Purpose | When required |
|---|---|---|
| `STRIPE_SECRET_KEY` | `sk_live_...` or `sk_test_...` | billing activated |
| `STRIPE_WEBHOOK_SIGNING_SECRET` | `whsec_...` per endpoint | webhook wired |

## Knowledge base (knowledge.db)

A file called `knowledge.db` sits at the repo root. It's a SQLite
database with 10 tables (`components`, `dependencies`, `insights`,
`runbooks`, `business_logic`, etc.) that function as a shared notebook
between AI sessions.

**Why this matters for you:** when Session 1 discovers a quirk (say,
"Stripe webhooks for test mode don't include the `payment_intent`
field"), it appends an insight row. Session 7, starting fresh months
later, queries the same table and sees the fact without re-discovering
it.

**You don't interact with it directly.** The AI reads and writes it
following the protocol in [`AGENT.md`](AGENT.md). You can inspect it
manually if you're curious:

```bash
sqlite3 knowledge.db "SELECT topic, finding FROM insights ORDER BY discovered_at DESC LIMIT 10"
```

## FAQ

**Q: I don't know Elixir. Can I still use this?**
Yes. The AI writes the Elixir. You review the outcomes (pages work,
tests pass, payments go through). Pick up the language over time or
don't — both are fine.

**Q: What if I want React/Next.js instead of LiveView?**
This template is not for you. LiveView is a foundational decision —
swapping it breaks most of the rest. Fork and replace if you really
want to, but it'll be a major rewrite.

**Q: Do I need all the infrastructure (Hetzner, Cloudflare, Stripe,
SES, etc.) to try this?**
No. For local development you only need Postgres and Elixir. The AI
stops and asks before it needs external accounts.

**Q: How much does the full stack cost to run?**
- Hetzner CX22 VPS: ~€4/month
- Postgres on the VPS: $0 (runs on the same box)
- Cloudflare R2 + CDN: $0 up to 10 GB storage, no egress
- Backblaze B2: ~$0.005/GB/month
- Amazon SES: $0.10 per 1,000 emails
- Stripe: 2.9% + 30¢ per successful transaction (only if you charge money)
- Tailscale: $0 (free tier, up to 3 users, 100 devices)
- **Total fixed cost before revenue: ~€4–€8/month**

**Q: Can I use this with Claude Code? Cursor? Aider? Other agents?**
Yes — any agent that can read files, run shell commands, and commit to
git will work. The prompts above are agent-agnostic.

**Q: The AI agent started doing something I didn't ask for. How do I
stop it?**
Interrupt it and say "stop — only do what I explicitly asked." The
`CONVENTIONS.md` file explicitly says "don't add features beyond what
the task requires" but agents sometimes drift. Course-correct early.

**Q: What if I want a different database / language / hosting?**
Fork the repo and change `STACK.md`, then edit the affected recipes.
The contract is written down; change it honestly.

**Q: Do I need to understand what `knowledge.db` does?**
No. It's for the AI's benefit. You can ignore it.

**Q: Can I run the tests without setting up the full stack?**
Yes — `mix test` only needs Postgres. All the external services (SES,
Stripe, R2, B2) can stay unconfigured and the tests still pass.

**Q: What's the license?**
MIT. Do whatever you want.

## License

MIT. See [`LICENSE`](LICENSE) when I add one.
