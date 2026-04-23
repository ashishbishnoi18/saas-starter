#!/usr/bin/env bash
# backup.sh — daily Postgres backup to Backblaze B2 via restic.
#
# Runs pg_dump into a stream, pipes into restic which encrypts and
# deduplicates against a B2 bucket. Retention policy keeps 7 daily, 4
# weekly, 12 monthly snapshots.
#
# Required env vars (usually in /etc/saas_starter/env):
#   DATABASE_URL              e.g. postgres://user:pass@localhost/db
#   RESTIC_REPOSITORY         e.g. b2:my-bucket:/saas_starter-prod
#   RESTIC_PASSWORD           encryption passphrase (keep this safe!)
#   B2_ACCOUNT_ID             B2 application key id
#   B2_ACCOUNT_KEY            B2 application key secret
#
# Optional:
#   BACKUP_TAG                tag stamped on the snapshot (default: "daily")
#   PG_DUMP_ARGS              extra args to pg_dump (default: --no-owner --no-acl)
#
# Exit codes:
#   0 success, 1 missing env, 2 pg_dump failed, 3 restic failed
set -euo pipefail

required=(DATABASE_URL RESTIC_REPOSITORY RESTIC_PASSWORD B2_ACCOUNT_ID B2_ACCOUNT_KEY)
for var in "${required[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "backup.sh: $var is not set" >&2
    exit 1
  fi
done

tag="${BACKUP_TAG:-daily}"
pg_dump_args="${PG_DUMP_ARGS:---no-owner --no-acl}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
snapshot_name="saas_starter-${stamp}.sql"

if ! command -v pg_dump >/dev/null; then
  echo "backup.sh: pg_dump not found in PATH" >&2
  exit 2
fi
if ! command -v restic >/dev/null; then
  echo "backup.sh: restic not found in PATH (install with: apt install restic)" >&2
  exit 3
fi

# Ensure the restic repo exists. `init` is a no-op if already initialized.
restic init >/dev/null 2>&1 || true

# Stream pg_dump → restic. --stdin-filename names the virtual file inside
# the snapshot so you can identify it in `restic ls <snapshot-id>`.
if ! pg_dump $pg_dump_args "$DATABASE_URL" \
  | restic backup --stdin --stdin-filename "$snapshot_name" --tag "$tag"
then
  status=${PIPESTATUS[0]}
  if [[ "$status" -ne 0 ]]; then
    echo "backup.sh: pg_dump failed (exit $status)" >&2
    exit 2
  else
    echo "backup.sh: restic backup failed" >&2
    exit 3
  fi
fi

# Prune old snapshots per retention policy.
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --tag "$tag" \
  --prune

echo "backup.sh: ok — snapshot tagged '${tag}' at ${stamp}"
