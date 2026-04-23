defmodule SaasStarter.Repo do
  use Ecto.Repo,
    otp_app: :saas_starter,
    adapter: Ecto.Adapters.Postgres
end
