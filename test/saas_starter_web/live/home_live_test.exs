defmodule SaasStarterWeb.HomeLiveTest do
  use SaasStarterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SaasStarter.AccountsFixtures

  describe "GET /" do
    test "shows the home page with a login CTA when signed out", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#home-root")
      assert has_element?(view, "#cta-login")
      refute has_element?(view, "#cta-dashboard")
    end

    test "swaps the CTA to 'dashboard' when signed in", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#cta-dashboard")
      refute has_element?(view, "#cta-login")
    end
  end
end
