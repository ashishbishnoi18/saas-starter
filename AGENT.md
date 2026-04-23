# AGENT.md — Knowledge-base protocol

The project ships with a SQLite knowledge base at `knowledge.db` (created by
`./kb-init`). It's a structured notebook about this codebase — every AI
session that works here should **read it first, write to it on exit**.

Phoenix's coding-style rules live in `AGENTS.md` (plural). The stack is
declared in `STACK.md` — treat it as binding. Project-specific conventions
(forbidden patterns, decisions) live in `CONVENTIONS.md`. Task-shaped how-tos
live in `RECIPES/`. This file is specifically about the knowledge-base
workflow.

## Before you start a task

1. `sqlite3 knowledge.db "SELECT id, name, type FROM components"` — what's here
2. `sqlite3 knowledge.db "SELECT domain, rule FROM business_logic"` — rules
   that already apply
3. Relevant insights:
   `sqlite3 knowledge.db "SELECT topic, finding FROM insights WHERE tags LIKE '%<topic>%'"`

Never assume. If the knowledge base has a fact, it supersedes your guess.

## While you work

Append to `insights` whenever you learn something non-obvious:

```sql
INSERT INTO insights (component_id, topic, finding, evidence, confidence, tags)
VALUES ('accounts', 'oauth',
        'Google returns email_verified=false for test workspace users',
        'Hit 2026-04-24 during manual test; see conn.assigns.ueberauth_auth.extra',
        'confirmed',
        'oauth,google,edge_case');
```

Confidence levels: `confirmed`, `suspected`, `outdated`, `disproven`. Mark an
existing insight `outdated` instead of deleting — the history is useful.

## Before you stop

1. Log your work in `changelog`:

```sql
INSERT INTO changelog (component_id, action, what, files_changed, agent_session)
VALUES ('accounts', 'added',
        'Google OAuth via Ueberauth',
        'lib/saas_starter/accounts.ex,lib/saas_starter_web/controllers/oauth_controller.ex',
        'claude-2026-04-23-abc');
```

2. Update `components`, `dependencies`, `config`, `endpoints`, `schema_docs`,
   or `runbooks` if your change introduces/removes any of these.

## Do not write to knowledge.db from application code

`knowledge.db` is for humans and AI agents. The Phoenix app never opens it
at runtime — there's no Ecto repo configured for it. Query it from the shell.

## Hard rules (enforced by triggers)

- `config.value` must **not** contain the literal credential when
  `config.sensitive = 1`. Use `storage_location` to point to the real
  location (env var, vault path, file path). Triggers block obvious matches
  like `sk_*`, `postgres://*`, or strings longer than 50 chars.

## Schema quick reference

| Table | Use for |
|---|---|
| `components` | Every major building block. One row per OTP app, service, DB, module, worker. |
| `dependencies` | Who calls/reads/writes/imports whom. |
| `config` | Env vars, config file keys, feature flags. |
| `endpoints` | HTTP routes this app exposes or consumes. |
| `schema_docs` | Every DB table worth documenting. |
| `insights` | Append-only discovery log. |
| `secrets` | Pointers only — never values. |
| `runbooks` | Commands, cron schedules, deploy procedures. |
| `business_logic` | Rules, algorithms, domain invariants. |
| `changelog` | Audit trail of your changes. |

## Re-initializing

`./kb-init` is idempotent. Delete `knowledge.db` first if you want to start
from an empty schema.

## Commit cadence

Every cohesive change is one commit. Use `scripts/ai-commit.sh "<message>"`
which runs `mix format && mix compile --warnings-as-errors && mix test`
before it lets the commit through. If any gate fails, nothing is committed
— fix forward, re-run.

**Never** commit directly with `git commit` unless you've already run the
three checks manually. The log is a walkthrough for the next AI; keep it
green.
