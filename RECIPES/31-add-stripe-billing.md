# Activate Stripe billing

`stripity_stripe` is already in `mix.exs` (v0.1 declares it but doesn't
call it). Activating it is contained: wire the config, flip the impl
module, and add the webhook endpoint.

## Steps

### 1. Runtime config

```elixir
# config/runtime.exs
if config_env() != :test do
  config :stripity_stripe,
    api_key: System.get_env("STRIPE_SECRET_KEY") || raise("STRIPE_SECRET_KEY is missing"),
    signing_secret: System.get_env("STRIPE_WEBHOOK_SIGNING_SECRET")
end
```

### 2. Swap the Billing impl

```elixir
# config/config.exs
config :saas_starter, :billing, SaasStarter.Billing.Live
```

Tests stay on `SaasStarter.Billing.Stub`:

```elixir
# config/test.exs
config :saas_starter, :billing, SaasStarter.Billing.Stub
```

### 3. Write the Live impl

```elixir
# lib/saas_starter/billing/live.ex
defmodule SaasStarter.Billing.Live do
  @behaviour SaasStarter.Billing

  @impl true
  def charge(%{amount: amount, currency: currency, customer_id: customer_id}) do
    case Stripe.PaymentIntent.create(%{
           amount: amount,
           currency: currency,
           customer: customer_id,
           confirm: true
         }) do
      {:ok, intent} ->
        :telemetry.execute(
          [:saas_starter, :billing, :charge_ok],
          %{amount: amount},
          %{customer_id: customer_id}
        )
        {:ok, intent}

      {:error, %Stripe.Error{} = e} ->
        :telemetry.execute(
          [:saas_starter, :billing, :charge_failed],
          %{amount: amount},
          %{reason: inspect(e)}
        )
        {:error, e}
    end
  end
end
```

### 4. Webhook endpoint

```elixir
# lib/saas_starter_web/controllers/stripe_webhook_controller.ex
defmodule SaasStarterWeb.StripeWebhookController do
  use SaasStarterWeb, :controller

  def handle(conn, _params) do
    signing_secret = Application.get_env(:stripity_stripe, :signing_secret)
    signature = List.first(get_req_header(conn, "stripe-signature"))
    {:ok, raw_body, _conn} = Plug.Conn.read_body(conn, length: 10_000_000)

    case Stripe.Webhook.construct_event(raw_body, signature, signing_secret) do
      {:ok, event} ->
        _ = SaasStarter.Billing.Events.handle(event)
        send_resp(conn, 200, "ok")

      {:error, _} ->
        send_resp(conn, 400, "invalid signature")
    end
  end
end
```

### 5. Router

```elixir
# router.ex — outside the :browser pipeline so CSRF doesn't block it
pipeline :webhook do
  plug :accepts, ["json"]
end

scope "/webhooks", SaasStarterWeb do
  pipe_through :webhook
  post "/stripe", StripeWebhookController, :handle
end
```

You also need to add a raw-body cache plug (by default Phoenix consumes
the body before the controller sees it). Use `Stripe.WebhookPlug` or the
manual approach in the Stripity Stripe docs.

### 6. Tests

Use `Stripe.Webhook.construct_event/3` with a fixture event payload + a
test-signed signature to assert webhook handling. Don't hit the live Stripe
API in tests — use the stub for unit tests and Stripe's CLI
`stripe trigger` for local end-to-end verification.

## Hard rules

- **Never call `Stripe.*` directly from LiveViews or controllers.** Route
  everything through `SaasStarter.Billing.charge/1`.
- **Always verify webhook signatures.** An unsigned webhook is a forged
  webhook.
- **Prices and amounts are integer cents.** Never use float/Decimal for
  Stripe amounts.
- **Stripity Stripe was last updated May 2024.** If you hit a gap (new
  Stripe API features), check for a maintained fork before patching.
