defmodule SaasStarterWeb.StripeWebhookController do
  @moduledoc """
  Stripe webhook receiver. Verifies the signature against the configured
  signing secret, then dispatches the parsed event to the configured
  event handler (default `SaasStarter.Billing.EventHandler`).

  **Not** wired in the router in v0.1. To activate, see
  `RECIPES/31-add-stripe-billing.md`.

  ### Signature verification

  Stripe signs each webhook with the endpoint's signing secret. The
  controller reads the raw body (Plug.Conn.read_body) and the
  `stripe-signature` header, then asks `Stripe.Webhook.construct_event/3`
  to verify. If verification fails we return 400 and never touch the
  payload.
  """

  use SaasStarterWeb, :controller

  require Logger

  def handle(conn, _params) do
    signing_secret = Application.get_env(:stripity_stripe, :signing_secret)

    with {:ok, signature} <- fetch_signature(conn),
         {:ok, raw_body, conn} <- read_raw_body(conn),
         {:ok, %Stripe.Event{} = event} <-
           Stripe.Webhook.construct_event(raw_body, signature, signing_secret) do
      _ = event_handler().handle(event)
      send_resp(conn, 200, "ok")
    else
      {:error, reason} ->
        Logger.warning("[billing] webhook rejected: #{inspect(reason)}")
        send_resp(conn, 400, "invalid")
    end
  end

  defp fetch_signature(conn) do
    case get_req_header(conn, "stripe-signature") do
      [sig | _] -> {:ok, sig}
      _ -> {:error, :missing_signature}
    end
  end

  defp read_raw_body(conn) do
    case Plug.Conn.read_body(conn, length: 10_000_000) do
      {:ok, body, conn} -> {:ok, body, conn}
      other -> {:error, {:body_read_failed, other}}
    end
  end

  defp event_handler do
    Application.get_env(:saas_starter, :billing_event_handler, SaasStarter.Billing.EventHandler)
  end
end
