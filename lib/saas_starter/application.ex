defmodule SaasStarter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SaasStarterWeb.Telemetry,
      SaasStarter.Repo,
      {DNSCluster, query: Application.get_env(:saas_starter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SaasStarter.PubSub},
      {Task.Supervisor, name: SaasStarter.TaskSupervisor},
      SaasStarterWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SaasStarter.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Attach telemetry handlers that route Phoenix/LiveView events
      # into SaasStarter.Events.track/3 (see events/telemetry_handler.ex).
      SaasStarter.Events.TelemetryHandler.attach()
      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SaasStarterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
