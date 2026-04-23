# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :saas_starter, :scopes,
  user: [
    default: true,
    module: SaasStarter.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: SaasStarter.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :saas_starter,
  ecto_repos: [SaasStarter.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :saas_starter, SaasStarterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SaasStarterWeb.ErrorHTML, json: SaasStarterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SaasStarter.PubSub,
  live_view: [signing_salt: "gB62RUG2"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :saas_starter, SaasStarter.Mailer, adapter: Swoosh.Adapters.Local

# Ueberauth — Google OAuth only in v0.1. Client id/secret come from env
# (see config/runtime.exs). Add more providers by listing them in
# `providers:` and configuring their strategy here. See
# RECIPES/12-add-oauth-provider.md.
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Phoenix Replay — Ecto storage in the app's primary repo, sanitizer
# scrubs PII keys before serialization. See RECIPES/99-admin-replay.md
# (future) for a viewer LiveView; in v0.1 recordings just accumulate.
config :phoenix_replay,
  storage: PhoenixReplay.Storage.Ecto,
  storage_opts: [repo: SaasStarter.Repo, format: :etf],
  sanitizer: SaasStarter.ReplaySanitizer,
  max_events: 10_000

# ExAws is pointed at Cloudflare R2, not AWS S3. R2 is S3-compatible, so
# we override the endpoint. R2 requires region "auto". Bucket and HTTP
# credentials are loaded at runtime (config/runtime.exs) from env vars.
# SaasStarter.Storage emits its own telemetry span per call so outbound
# R2 traffic is observable even though we use hackney (ExAws default)
# rather than our Req wrapper.
config :ex_aws,
  json_codec: Jason,
  region: "auto"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  saas_starter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  saas_starter: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
