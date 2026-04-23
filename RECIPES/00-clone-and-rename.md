# Clone and rename the starter

This template is named `saas_starter` / `SaasStarter`. Rename both the OTP
app and the root module to your project's name before committing anything
new.

## Steps

Assume target name: `my_app` / `MyApp`.

```bash
# 1. Clone
git clone <this-repo>.git my_app
cd my_app

# 2. Recursive find-replace, excluding _build, deps, and binaries
#    (Use `grep -rl` to verify the targets before sed runs.)
find . -type f \
  \( -name '*.ex' -o -name '*.exs' -o -name '*.heex' \
     -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \
     -o -name 'mix.exs' -o -name 'mix.lock' \) \
  -not -path './_build/*' -not -path './deps/*' -not -path './.git/*' \
  -exec sed -i \
    -e 's/SaasStarter/MyApp/g' \
    -e 's/saas_starter/my_app/g' \
    -e 's/saas-starter/my-app/g' \
    {} +

# 3. Rename module directories
mv lib/saas_starter     lib/my_app
mv lib/saas_starter_web lib/my_app_web

# 4. Rename top-level files that embed the name
mv lib/saas_starter.ex     lib/my_app.ex     2>/dev/null || true
mv lib/saas_starter_web.ex lib/my_app_web.ex 2>/dev/null || true

# 5. Verify nothing was missed
grep -rn 'saas_starter\|SaasStarter' \
  --exclude-dir=_build --exclude-dir=deps --exclude-dir=.git \
  || echo "clean"

# 6. Fresh compile + test
mix deps.get
mix ecto.reset
mix test
```

## After rename

1. Delete `priv/repo/seeds.exs` if it has starter-specific data.
2. Update `README.md` and `CONVENTIONS.md` to reflect your project, not the
   generic starter text.
3. Commit: `git commit -am "Rename to my_app"`.
4. Delete this recipe (`RECIPES/00-clone-and-rename.md`) — it's only
   relevant during the initial fork.

## Knowledge base

Run `./kb-init` once in the new repo to refresh `knowledge.db` (idempotent,
but removes nothing). Then `./kb-init` is never run again unless you want
a full reset.

## Postgres

The `mix ecto.reset` step assumes Postgres is running locally and your
user can CREATE DATABASE. If not, create the DBs manually and re-run
`mix ecto.setup`:

```bash
createdb my_app_dev
createdb my_app_test
mix ecto.setup
```
