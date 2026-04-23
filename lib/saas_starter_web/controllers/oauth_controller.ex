defmodule SaasStarterWeb.OAuthController do
  @moduledoc """
  Ueberauth OAuth callbacks. Each provider configured in `config :ueberauth`
  routes here via `/auth/:provider/callback`. The `Ueberauth` plug populates
  `conn.assigns.ueberauth_auth` on success and `:ueberauth_failure` on
  failure.

  On success we upsert the user via `Accounts.upsert_user_from_oauth/1` and
  hand the session off to the shared `UserAuth.log_in_user/2` so OAuth
  sign-ins and magic-link sign-ins land on the same session plumbing.
  """
  use SaasStarterWeb, :controller

  plug Ueberauth

  alias SaasStarter.Accounts
  alias SaasStarterWeb.UserAuth

  # Unreachable under normal flow — the Ueberauth plug short-circuits
  # `/auth/:provider` with a redirect to the provider. Defined so the
  # router compiles without warnings.
  def request(conn, _params), do: conn

  def callback(%{assigns: %{ueberauth_failure: %{errors: errors}}} = conn, _params) do
    message = errors |> Enum.map(& &1.message) |> Enum.join(", ")

    conn
    |> put_flash(:error, "Authentication failed: #{message}")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "google"}) do
    attrs = %{
      email: auth.info.email,
      google_sub: to_string(auth.uid)
    }

    case Accounts.upsert_user_from_oauth(attrs) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not sign you in. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
