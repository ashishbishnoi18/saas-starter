defmodule SaasStarter.Events.TelemetryHandler do
  @moduledoc """
  Attaches `:telemetry` events to `SaasStarter.Events.track/3` so every
  LiveView mount, LiveView event, and selected Phoenix router dispatch
  becomes a durable `product_events` row.

  Call `attach/0` from the Application supervision tree once on boot.
  Detach in tests via `:telemetry.detach(@handler_id)`.
  """

  require Logger

  alias SaasStarter.Events

  @handler_id "saas-starter-events-handler"

  @events [
    [:phoenix, :live_view, :mount, :stop],
    [:phoenix, :live_view, :handle_event, :stop]
  ]

  @doc "Attach all built-in handlers. Safe to call multiple times."
  def attach do
    _ = :telemetry.detach(@handler_id)
    :telemetry.attach_many(@handler_id, @events, &__MODULE__.handle_event/4, %{})
  end

  @doc false
  def handle_event([:phoenix, :live_view, :mount, :stop], _measurements, meta, _config) do
    user = get_current_user(meta)
    name = "live.mount"
    metadata = %{view: inspect(meta[:socket] && meta.socket.view)}
    _ = track_async(user, name, metadata)
    :ok
  end

  def handle_event([:phoenix, :live_view, :handle_event, :stop], _measurements, meta, _config) do
    user = get_current_user(meta)
    name = "live.event"

    metadata = %{
      view: inspect(meta[:socket] && meta.socket.view),
      event: meta[:event]
    }

    _ = track_async(user, name, metadata)
    :ok
  end

  # Telemetry handlers run in the calling process; insert in a Task to
  # avoid adding DB latency to the hot LiveView render path.
  defp track_async(user, name, metadata) do
    Task.Supervisor.start_child(SaasStarter.TaskSupervisor, fn ->
      case Events.track(user, name, metadata) do
        {:ok, _} -> :ok
        {:error, changeset} -> Logger.warning("event track failed: #{inspect(changeset)}")
      end
    end)
  end

  defp get_current_user(%{socket: %{assigns: %{current_scope: %{user: user}}}}), do: user
  defp get_current_user(_), do: nil
end
