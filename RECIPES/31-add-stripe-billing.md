# Activate Stripe billing

`stripity_stripe` is declared in `mix.exs` and the Live implementation
(`SaasStarter.Billing.Live`) + webhook controller
(`SaasStarterWeb.StripeWebhookController`) ship in the starter but are
**not activated** by default. This recipe wires them up.

## 1. Runtime config

```elixir
# config/runtime.exs — outside the :prod block if you want it in dev too
config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET_KEY") || raise("STRIPE_SECRET_KEY is missing"),
  signing_secret: System.get_env("STRIPE_WEBHOOK_SIGNING_SECRET") ||
    raise("STRIPE_WEBHOOK_SIGNING_SECRET is missing")
```

## 2. Swap the default Billing impl from Stub to Live

```elixir
# config/config.exs
config :saas_starter, :billing, SaasStarter.Billing.Live

# config/test.exs — tests stay on Stub so CI doesn't need Stripe creds
config :saas_starter, :billing, SaasStarter.Billing.Stub
```

## 3. Write your app's event handler

The shipped `SaasStarter.Billing.EventHandler` is a no-op. Override it:

```elixir
# lib/my_app/billing/event_handler.ex
defmodule MyApp.Billing.EventHandler do
  alias MyApp.{Accounts, Subscriptions}

  def handle(%Stripe.Event{type: "checkout.session.completed", data: %{object: session}}) do
    user_id = session.metadata["user_id"]
    Subscriptions.activate(user_id, session.customer, session.subscription)
  end

  def handle(%Stripe.Event{type: "customer.subscription.deleted", data: %{object: sub}}) do
    Subscriptions.mark_canceled(sub.customer)
  end

  def handle(_other), do: :ok
end
```

Point the controller at it:

```elixir
# config/config.exs
config :saas_starter, :billing_event_handler, MyApp.Billing.EventHandler
```

## 4. Mount the webhook route

```elixir
# router.ex
pipeline :webhook do
  plug :accepts, ["json"]
end

scope "/webhooks", SaasStarterWeb do
  pipe_through :webhook
  post "/stripe", StripeWebhookController, :handle
end
```

The controller reads the raw request body via `Plug.Conn.read_body/2` —
no special plug needed to preserve it, as long as you don't wrap the
route in a pipeline that calls `Plug.Parsers` first. (The `:webhook`
pipeline above deliberately omits it.)

## 5. Stripe dashboard

- **Products + prices** — create your plan(s). Copy the price IDs
  (`price_xxx`).
- **Webhook endpoint** — add `https://your-host/webhooks/stripe` subscribed
  to at least:
  - `checkout.session.completed`
  - `customer.subscription.created` / `.updated` / `.deleted`
  - `invoice.payment_failed` (for dunning)
- Copy the signing secret (`whsec_xxx`) into `STRIPE_WEBHOOK_SIGNING_SECRET`.

## 6. Call it from a LiveView

```elixir
def handle_event("upgrade", _params, socket) do
  user = socket.assigns.current_scope.user

  {:ok, session} =
    SaasStarter.Billing.charge(%{
      price_id: "price_1234...",
      customer_email: user.email,
      mode: :subscription,
      success_url: url(socket, ~p"/dashboard?upgraded=1"),
      cancel_url: url(socket, ~p"/pricing")
    })

  {:noreply, redirect(socket, external: session.url)}
end
```

## 7. Local testing

Use Stripe CLI:

```bash
stripe login
stripe listen --forward-to localhost:4000/webhooks/stripe
# in another terminal — trigger events
stripe trigger checkout.session.completed
```

Stripe CLI prints the correct signing secret for the listener session;
export it as `STRIPE_WEBHOOK_SIGNING_SECRET` while testing.

## Hard rules

- **Never call `Stripe.*` directly** from LiveViews or contexts. Route
  through `SaasStarter.Billing.charge/1`. The Stub impl keeps tests
  deterministic.
- **Always verify webhook signatures.** An unsigned webhook is a forged
  webhook; the controller rejects with 400 if signature is missing or
  invalid.
- **Amounts are integer cents.** Never use `Decimal` or floats in Stripe
  API params.
- **Use Checkout, not raw PaymentIntents**, unless you have a strong
  reason. Checkout offloads PCI scope entirely.
- **stripity_stripe was last updated May 2024.** If you hit a gap against
  newer Stripe API features, check for a maintained fork before patching.
