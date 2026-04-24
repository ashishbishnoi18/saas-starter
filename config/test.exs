import Config

# Configure your database. Same env-override pattern as config/dev.exs:
#   PGUSER / PGPASSWORD / PGHOST (defaults match CI's postgres container).
# A PGHOST starting with "/" is treated as a Unix-socket directory.
# MIX_TEST_PARTITION enables built-in test partitioning in CI.
pg_host = System.get_env("PGHOST") || "localhost"

pg_conn_opts =
  if String.starts_with?(pg_host, "/"),
    do: [socket_dir: pg_host],
    else: [hostname: pg_host]

config :saas_starter,
       SaasStarter.Repo,
       [
         username: System.get_env("PGUSER") || "postgres",
         password: System.get_env("PGPASSWORD") || "postgres",
         database: "saas_starter_test#{System.get_env("MIX_TEST_PARTITION")}",
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: System.schedulers_online() * 2
       ] ++ pg_conn_opts

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :saas_starter, SaasStarterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "EesrY04XBSqriTK0d4OdYKOFqF/7/aUtv36sy4JyPcVxK55nnZU6437MgeVXLdvm",
  server: false

# In test we don't send emails
config :saas_starter, SaasStarter.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
