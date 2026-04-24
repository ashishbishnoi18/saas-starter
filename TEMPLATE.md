# TEMPLATE.md — the AI agent prompt

This file IS the prompt. Paste it verbatim into your AI agent of choice,
or tell the agent "follow TEMPLATE.md from
https://github.com/ashishbishnoi18/saas-starter" and it will read and
execute it itself.

Two modes: pick one and delete the other before pasting.

---

## Mode A — start a new SaaS from the template

```text
I'm building a new SaaS called {YOUR_APP_NAME} ({YourAppModule}). Use
my starter template as the foundation.

Source: https://github.com/ashishbishnoi18/saas-starter (main)

## Onboarding procedure (do these IN ORDER, no skipping)

1. Clone the source into the current directory.
2. Read these files top to bottom. They are the contract.
   - STACK.md          — the binding stack (DB, auth, hosting, etc.)
   - AGENTS.md         — Phoenix 1.8 / LiveView / Elixir coding rules
   - AGENT.md          — knowledge.db protocol + commit-cadence rules
   - CONVENTIONS.md    — forbidden patterns + decisions
   - RECIPES/00-clone-and-rename.md
3. Run the rename procedure from RECIPES/00, replacing
   saas_starter → {your_app_name} and SaasStarter → {YourAppModule}
   everywhere. After the rename, delete
   RECIPES/00-clone-and-rename.md and RECIPES/90-port-from-go.md
   (not applicable for a fresh project).
4. Copy .env.example to .env. Stop and tell me which env vars you
   need for the first feature; I'll fill them in.
5. Run `./kb-init` to refresh knowledge.db.
6. Run `mix setup` and `mix test`. Must be green before any feature
   work. If Postgres isn't reachable, stop and ask me to create the
   role.
7. Query knowledge.db for existing context:
      sqlite3 knowledge.db "SELECT name, type FROM components"
      sqlite3 knowledge.db "SELECT domain, rule FROM business_logic"

## First feature

{Describe your first feature concretely. Example: "Build a /pricing
LiveView with three tiers. Add a dashboard widget that shows
'Welcome, {user.email}' and links to the upgrade flow." Be specific
enough that 'done' is obvious.}

## Ground rules

- Use `scripts/ai-commit.sh "<message>"` for every commit. It runs
  format + compile --warnings-as-errors + test as a gate. Fix forward
  when it fails.
- One commit per cohesive change. The log is the walkthrough for the
  next session.
- After each meaningful change, append to knowledge.db's `changelog`
  table and any relevant `insights`.
- Do NOT modify STACK.md or CONVENTIONS.md without surfacing the
  change to me first.
- If you need an external account or credential (OAuth creds, Stripe
  keys, Hetzner VPS, Cloudflare R2, etc.), stop and tell me exactly
  what you need and why. Don't fake it.
- Activation recipes for billing, email, deployment, etc. live in
  RECIPES/. Read the relevant one before wiring its component.

Stop and ask me if anything is ambiguous.
```

---

## Mode B — port an existing codebase onto the template

```text
I want to port my existing project at {ABSOLUTE_PATH_TO_OLD_CODE}
onto my starter template. Target name: {new_app_name} / {NewAppModule}.
Source language of the old code: {e.g. Go, Python, Ruby}.

Source template: https://github.com/ashishbishnoi18/saas-starter (main)

## Onboarding procedure

1. Clone the template into {target-path}/.
2. Read (in order):
   - STACK.md
   - AGENTS.md
   - AGENT.md
   - CONVENTIONS.md
   - RECIPES/00-clone-and-rename.md
   - RECIPES/90-port-from-go.md (adapt for {source language} if not Go)
3. Run the rename procedure. Delete RECIPES/00 after.
   KEEP RECIPES/90 — it's the migration guide.
4. Copy .env.example to .env.
5. `./kb-init` + `mix setup` + `mix test` must be green before any
   migration work.

## Migration plan (phase-by-phase, stop after each)

Phase 1 — Scaffold:
  Clone template, rename, green test suite. Translate the existing
  data model to Ecto schemas + migrations. DO NOT migrate data yet.

Phase 2 — Data migration dry run:
  Mix task that copies data from the old source into the new Postgres.
  Run against a copy, not the live DB. Verify row counts.

Phase 3 — Logic port:
  Port existing business logic to Elixir contexts. Every ported
  function gets a test. All outbound HTTP through SaasStarter.HTTP.
  Background jobs via Oban (activate via RECIPES/30-add-oban.md).

Phase 4 — UI:
  Build the LiveView UI. Mark the old codebase read-only and point
  traffic at the new app gradually.

Phase 5 — Decommission:
  After two weeks of stable operation, retire the old codebase. Log
  retirement in knowledge.db's changelog table.

## Ground rules

Same as Mode A: `scripts/ai-commit.sh` for every commit, one commit
per cohesive change, knowledge.db updated as you learn.

- Preserve raw data during migration. Never drop source data; copy
  to a new table, verify, then cut over.
- If a port needs a component not in the template yet (Oban, Stripe,
  R2, SES), activate it via the matching RECIPES file. Don't reinvent.

STOP and ask between every phase. Don't run Phase N+1 until I've
reviewed Phase N.
```
