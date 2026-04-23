defmodule SaasStarter.Billing.Live do
  @moduledoc """
  Real Stripe-backed implementation of `SaasStarter.Billing`.

  **Not** activated in v0.1 — the default `:billing` impl is
  `SaasStarter.Billing.Stub`. Flip to this module via
  `config :saas_starter, :billing, SaasStarter.Billing.Live` after
  running through `RECIPES/31-add-stripe-billing.md`.

  Wraps the minimum Stripe surface every SaaS needs:

    * `charge/1` creates a **Checkout Session** (hosted-page flow — the
      user pays on stripe.com, we never touch card data). Pass
      `%{price_id: "...", customer_email: "...", success_url: "...",
      cancel_url: "...", mode: :subscription | :payment}`.
    * Webhook handling lives in `SaasStarterWeb.StripeWebhookController`
      and delegates each verified event to
      `SaasStarter.Billing.EventHandler` — override that module per app
      to react to subscription state changes.

  Direct Stripe API calls from LiveViews/contexts are forbidden; route
  them through `SaasStarter.Billing.charge/1`.
  """

  @behaviour SaasStarter.Billing

  @impl true
  def charge(%{price_id: price_id} = params) when is_binary(price_id) do
    mode =
      case params[:mode] do
        :subscription -> "subscription"
        :payment -> "payment"
        nil -> "payment"
      end

    session_params = %{
      mode: mode,
      line_items: [%{price: price_id, quantity: Map.get(params, :quantity, 1)}],
      success_url: fetch!(params, :success_url),
      cancel_url: fetch!(params, :cancel_url)
    }

    session_params =
      case params[:customer_email] do
        nil -> session_params
        email -> Map.put(session_params, :customer_email, email)
      end

    case Stripe.Checkout.Session.create(session_params) do
      {:ok, session} ->
        :telemetry.execute(
          [:saas_starter, :billing, :checkout_created],
          %{},
          %{mode: mode, session_id: session.id}
        )

        {:ok, session}

      {:error, %Stripe.Error{} = err} ->
        :telemetry.execute(
          [:saas_starter, :billing, :checkout_failed],
          %{},
          %{reason: inspect(err)}
        )

        {:error, err}
    end
  end

  def charge(_), do: {:error, :price_id_required}

  defp fetch!(map, key) do
    Map.get(map, key) || raise ArgumentError, "Billing.Live.charge requires :#{key}"
  end
end
