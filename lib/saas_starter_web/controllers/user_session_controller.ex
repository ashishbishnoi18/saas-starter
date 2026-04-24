defmodule SaasStarterWeb.UserSessionController do
  @moduledoc """
  Session create/delete. v0.1 ships with magic-link login only — the
  password path was intentionally stripped (see STACK.md). Google OAuth
  goes through `SaasStarterWeb.OAuthController`, which also calls
  `UserAuth.log_in_user/2` so both surfaces share the same session
  plumbing.
  """

  use SaasStarterWeb, :controller

  alias SaasStarter.Accounts
  alias SaasStarterWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
