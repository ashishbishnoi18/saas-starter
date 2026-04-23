defmodule SaasStarterWeb.OAuthControllerTest do
  use SaasStarterWeb.ConnCase, async: true

  alias SaasStarter.Accounts
  alias SaasStarter.Repo

  describe "callback/2 with a Google success" do
    test "creates a new user, signs them in, and redirects", %{conn: conn} do
      email = "oauth-#{System.unique_integer()}@example.com"

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google-sub-#{System.unique_integer()}",
        info: %Ueberauth.Auth.Info{email: email}
      }

      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, auth)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) in [~p"/", ~p"/users/settings"]

      user = Accounts.get_user_by_email(email)
      assert user
      assert user.google_sub == auth.uid
      assert user.confirmed_at
    end

    test "attaches google_sub to an existing magic-link user with the same email", %{conn: conn} do
      user = SaasStarter.AccountsFixtures.user_fixture()

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google-sub-#{System.unique_integer()}",
        info: %Ueberauth.Auth.Info{email: user.email}
      }

      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_auth, auth)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn)

      updated = Repo.reload!(user)
      assert updated.google_sub == auth.uid
    end
  end

  describe "callback/2 with Ueberauth failure" do
    test "flashes an error and redirects to login", %{conn: conn} do
      failure = %Ueberauth.Failure{
        errors: [%Ueberauth.Failure.Error{message_key: "e", message: "oauth denied"}],
        provider: :google,
        strategy: Ueberauth.Strategy.Google
      }

      conn =
        conn
        |> init_test_session(%{})
        |> assign(:ueberauth_failure, failure)
        |> get(~p"/auth/google/callback")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "oauth denied"
    end
  end
end
