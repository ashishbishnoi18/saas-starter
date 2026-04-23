# Set up daily Postgres backups to Backblaze B2

`scripts/backup.sh` is a restic-based backup that streams `pg_dump` into
an encrypted, deduplicated repository in a Backblaze B2 bucket.

## 1. Create a B2 bucket and application key

1. Sign in at https://www.backblaze.com
2. **Buckets** → Create — name e.g. `mycompany-backups`; private; lifecycle
   "Keep only the last version" is fine (restic does its own retention).
3. **Application Keys** → Add — grant `readFiles + writeFiles + listFiles +
   deleteFiles` on that one bucket only. Copy:
   - `keyID` → becomes `B2_ACCOUNT_ID`
   - `applicationKey` → becomes `B2_ACCOUNT_KEY`

## 2. Install restic on the VPS

```bash
sudo apt-get update
sudo apt-get install -y restic postgresql-client
restic version                    # sanity check
```

## 3. Pick an encryption password

**Store this in a password manager.** Without it the backups are useless.

```bash
openssl rand -base64 32           # generate something strong
```

## 4. Wire the env vars

Create `/etc/saas_starter/env` (readable only by the service user):

```
DATABASE_URL=postgres://saas_starter:<pw>@localhost/saas_starter_prod
RESTIC_REPOSITORY=b2:mycompany-backups:/saas_starter-prod
RESTIC_PASSWORD=<the output of openssl rand above>
B2_ACCOUNT_ID=<from step 1>
B2_ACCOUNT_KEY=<from step 1>
```

Protect the file:
```bash
sudo chown root:saas_starter /etc/saas_starter/env
sudo chmod 640 /etc/saas_starter/env
```

## 5. Manual first run

```bash
sudo -u saas_starter -- bash -c 'set -a; source /etc/saas_starter/env; /var/www/saas-starter/scripts/backup.sh'
```

The first run initializes the restic repository. Subsequent runs reuse it.

Verify:
```bash
restic snapshots        # should list one snapshot tagged "daily"
restic stats --mode raw-data    # shows total bytes backed up
```

## 6. Schedule daily

Add a cron entry for the service user:

```bash
sudo crontab -u saas_starter -e
```

```
# Daily 03:15 UTC Postgres backup
15 3 * * * set -a; source /etc/saas_starter/env; /var/www/saas-starter/scripts/backup.sh >> /var/log/saas_starter/backup.log 2>&1
```

## 7. Test a restore (do this NOW, not during an incident)

```bash
# Pick a snapshot id from `restic snapshots`
restic dump <snapshot-id> saas_starter-<stamp>.sql > /tmp/restore.sql
# Eyeball it — should look like a Postgres dump
head -20 /tmp/restore.sql
# And actually restore into a throwaway DB
createdb saas_starter_restore_test
psql saas_starter_restore_test < /tmp/restore.sql
dropdb saas_starter_restore_test
```

**A backup you haven't restored is a file, not a backup.** Run a restore
drill quarterly.

## Retention policy

Set in `backup.sh`:
- 7 daily
- 4 weekly
- 12 monthly

Adjust `--keep-daily/weekly/monthly` if your recovery-point-objective
differs.

## Monitoring

The script returns non-zero on failure — cron will email the service
user's mbox. For stronger alerting pipe to a healthcheck service
(healthchecks.io is free):

```
... /var/www/saas-starter/scripts/backup.sh && curl -fsS --retry 3 https://hc-ping.com/<uuid> || curl -fsS --retry 3 https://hc-ping.com/<uuid>/fail
```

## Pitfalls

- **Losing `RESTIC_PASSWORD`** = losing the backups. Store it separately
  from the VPS itself (password manager, second vault).
- **Running as root** — the script doesn't need it. Run as the service
  user and grant Postgres SELECT to that user.
- **Forgetting to prune** — not a problem here; `restic forget --prune`
  in the script keeps bucket size bounded.
- **B2 egress cost** — free up to 3× your stored bytes per day. Restores
  from catastrophic incidents may exceed; budget $0.01/GB for large
  restores.
