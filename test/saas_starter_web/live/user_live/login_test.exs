defmodule SaasStarterWeb.UserLive.LoginTest do
  use SaasStarterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SaasStarter.AccountsFixtures

  describe "login page" do
    test "renders both Google and magic-link surfaces", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "#google-login")
      assert has_element?(view, "#login_form_magic")
      refute has_element?(view, "#login_form_password")
    end

    test "Google button links to /auth/google", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, ~s|a#google-login[href="/auth/google"]|)
      assert html =~ "Continue with Google"
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert SaasStarter.Repo.get_by!(SaasStarter.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose whether the email is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "You need to reauthenticate"

      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_magic_email" value="#{user.email}")
    end
  end
end
