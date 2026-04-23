# Deploy to a Hetzner VPS

One-VPS, no-container deploy using a mix release + systemd + nginx +
Let's Encrypt. Tested on Ubuntu 24.04 on the smallest Hetzner CX22 box
(~€4/mo). Scale up when traffic warrants.

## 0. Prerequisites (local)

```bash
mix phx.gen.release            # generate bin/server + Dockerfile (we use just bin/server)
```

## 1. Provision the VPS

- **Hetzner Cloud console** → Create server
  - Image: Ubuntu 24.04
  - Type: CX22 (2 vCPU, 4 GB RAM) to start
  - Location: closest to users
  - SSH key: add yours
  - Firewall: attach one that allows 22 (ssh), 80, 443 only
- Assign a reverse DNS entry on the server's IPv4 → `<app>.example.com`

## 2. Initial hardening (~10 min)

SSH in as `root`, then:

```bash
# Non-root service user
useradd --system --create-home --shell /bin/bash saas_starter

# Unattended security updates
apt-get update && apt-get -y upgrade
apt-get install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

# UFW firewall (belt + braces with the Hetzner firewall)
apt-get install -y ufw
ufw allow OpenSSH
ufw allow http
ufw allow https
ufw --force enable

# Disable root SSH + password auth
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```

## 3. Install dependencies

```bash
# Postgres 16
apt-get install -y postgresql postgresql-contrib
sudo -u postgres createuser --pwprompt saas_starter
sudo -u postgres createdb -O saas_starter saas_starter_prod

# nginx + certbot
apt-get install -y nginx certbot python3-certbot-nginx

# Tailscale (for admin-only routes)
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --ssh         # follow the auth link, approve in your tailnet
```

## 4. First release build (local → push → extract)

```bash
# Local
MIX_ENV=prod mix release
scp _build/prod/saas_starter-0.1.0.tar.gz root@<ip>:/tmp/

# On VPS
sudo -u saas_starter mkdir -p /var/www/saas_starter/releases
sudo -u saas_starter tar -xzf /tmp/saas_starter-0.1.0.tar.gz \
  -C /var/www/saas_starter
```

*(Once this is working, wire a GitHub Action to do the build+push step —
not in v0.1.)*

## 5. Env file

```bash
sudo mkdir -p /etc/saas_starter
sudo tee /etc/saas_starter/env <<'EOF'
DATABASE_URL=ecto://saas_starter:<pw>@localhost/saas_starter_prod
SECRET_KEY_BASE=<mix phx.gen.secret>
PHX_HOST=app.example.com
PHX_SERVER=true
PORT=4000
FROM_EMAIL=no-reply@send.example.com
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=<ses>
SMTP_PASSWORD=<ses>
GOOGLE_CLIENT_ID=<from google console>
GOOGLE_CLIENT_SECRET=<from google console>
ADMIN_EMAILS=you@example.com
# Backup (see RECIPES/50)
RESTIC_REPOSITORY=b2:mycompany-backups:/saas_starter-prod
RESTIC_PASSWORD=<strong random>
B2_ACCOUNT_ID=<from b2>
B2_ACCOUNT_KEY=<from b2>
EOF

sudo chown root:saas_starter /etc/saas_starter/env
sudo chmod 640 /etc/saas_starter/env
```

## 6. systemd unit

```bash
sudo tee /etc/systemd/system/saas_starter.service <<'EOF'
[Unit]
Description=SaasStarter Phoenix app
After=network.target postgresql.service

[Service]
Type=exec
User=saas_starter
Group=saas_starter
WorkingDirectory=/var/www/saas_starter
EnvironmentFile=/etc/saas_starter/env
ExecStart=/var/www/saas_starter/bin/saas_starter start
ExecStop=/var/www/saas_starter/bin/saas_starter stop
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/www/saas_starter/tmp
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now saas_starter
sudo systemctl status saas_starter     # should be "active (running)"
```

Migrations:

```bash
sudo -u saas_starter bash -c 'set -a; source /etc/saas_starter/env; /var/www/saas_starter/bin/saas_starter eval "SaasStarter.Release.migrate()"'
```

*(If you don't have a `Release` module yet, add one via
`mix phx.gen.release` or write this manually:)*

```elixir
# lib/saas_starter/release.ex
defmodule SaasStarter.Release do
  @app :saas_starter
  def migrate do
    load_app()
    for repo <- repos(), do: {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end
  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
  defp load_app do
    Application.load(@app)
  end
end
```

## 7. nginx + TLS

```bash
sudo tee /etc/nginx/sites-available/saas_starter <<'EOF'
server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;

        # LiveView WebSocket upgrade
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 90s;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/saas_starter /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Let's Encrypt — automatic cert + redirect to https
sudo certbot --nginx -d app.example.com --redirect --non-interactive --agree-tos --email you@example.com
```

## 8. Admin panel exposure

Public nginx serves the whole app — but `SaasStarterWeb.Plugs.AdminGate`
rejects any `/admin/*` request from a non-Tailscale IP. That means admin
is **implicitly protected** by the gate even though it's routed through
the same public endpoint.

If you want belt-and-braces, use a **second** Phoenix endpoint bound only
to the Tailscale interface. Not in v0.1; add it when you're paranoid.

## 9. Subsequent deploys

```bash
# Local
MIX_ENV=prod mix release
scp _build/prod/saas_starter-<version>.tar.gz root@<ip>:/tmp/

# On VPS
sudo systemctl stop saas_starter
sudo -u saas_starter tar -xzf /tmp/saas_starter-<version>.tar.gz \
  -C /var/www/saas_starter --overwrite
sudo -u saas_starter bash -c 'set -a; source /etc/saas_starter/env; /var/www/saas_starter/bin/saas_starter eval "SaasStarter.Release.migrate()"'
sudo systemctl start saas_starter
```

No zero-downtime yet — OK for single-VPS indie. Add blue/green when your
traffic can't tolerate ~5s of downtime during deploy.

## 10. Observability

- `journalctl -u saas_starter -f` — live logs
- `systemctl status saas_starter` — running state
- LiveDashboard is disabled in prod by default (only `:dev_routes`);
  mount it behind `/admin` if you want it in prod (uses AdminGate)

## Common pitfalls

- **Forgetting `proxy_set_header Upgrade / Connection` in nginx** —
  WebSocket breaks, LiveView stops reconnecting.
- **`PHX_SERVER` not set** — the release starts but doesn't listen on a
  port. The env file includes it, but double-check.
- **Port 25 egress blocked** — don't try raw SMTP on port 25 from Hetzner;
  use SES SMTP on 587.
- **Postgres not restarted after `pg_hba.conf` changes** — peer auth
  surprises.
- **Timezones** — `systemd-journald` defaults to UTC. Keep it. Set
  `config :logger, default_formatter: [time: :utc]`.
