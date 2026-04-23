defmodule SaasStarterWeb.DashboardLiveTest do
  use SaasStarterWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SaasStarter.AccountsFixtures

  describe "GET /dashboard" do
    test "redirects to log-in when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
      assert path =~ "/users/log-in"
    end

    test "renders the dashboard when signed in", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#dashboard-root")
      assert has_element?(view, "#dashboard-email", user.email)
    end
  end
end
