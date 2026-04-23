defmodule SaasStarter.Billing.EventHandler do
  @moduledoc """
  Default Stripe webhook event dispatcher. Apps typically override this
  per-project — the starter ships a no-op implementation so the webhook
  pipeline compiles end-to-end without requiring app-specific logic.

  ### Overriding

  Subclass or replace in your project:

      defmodule MyApp.Billing.EventHandler do
        alias MyApp.{Accounts, Subscriptions}

        def handle(%Stripe.Event{type: "checkout.session.completed", data: %{object: s}}) do
          Subscriptions.activate(s.customer, s.metadata["user_id"])
        end

        def handle(_event), do: :ok
      end

  Then point the webhook controller at your module via
  `config :saas_starter, :billing_event_handler, MyApp.Billing.EventHandler`.
  """

  require Logger

  @doc """
  Default: log the event type at info level and return `:ok`. Override
  per-project.
  """
  @spec handle(Stripe.Event.t() | map()) :: :ok
  def handle(%{type: type}) when is_binary(type) do
    Logger.info("[billing] received Stripe event #{type} — no handler configured")
    :ok
  end

  def handle(_other), do: :ok
end
