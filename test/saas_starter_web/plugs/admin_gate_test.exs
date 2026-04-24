defmodule SaasStarterWeb.Plugs.AdminGateTest do
  use SaasStarterWeb.ConnCase, async: false

  import SaasStarter.AccountsFixtures

  alias SaasStarterWeb.Plugs.AdminGate

  @tailscale_v4 {100, 100, 0, 1}
  @tailscale_v6 {0xFD7A, 0x115C, 0xA1E0, 0, 0, 0, 0, 1}
  @public_v4 {203, 0, 113, 5}

  describe "tailscale_ip?/1" do
    test "recognizes CGNAT v4 range" do
      assert AdminGate.tailscale_ip?({100, 64, 0, 0})
      assert AdminGate.tailscale_ip?({100, 100, 5, 99})
      assert AdminGate.tailscale_ip?({100, 127, 255, 255})
    end

    test "rejects v4 outside CGNAT" do
      refute AdminGate.tailscale_ip?({100, 63, 0, 0})
      refute AdminGate.tailscale_ip?({100, 128, 0, 0})
      refute AdminGate.tailscale_ip?({10, 0, 0, 1})
      refute AdminGate.tailscale_ip?({127, 0, 0, 1})
      refute AdminGate.tailscale_ip?({192, 168, 1, 1})
      refute AdminGate.tailscale_ip?(@public_v4)
    end

    test "recognizes Tailscale v6 range" do
      assert AdminGate.tailscale_ip?(@tailscale_v6)
    end

    test "rejects v6 outside Tailscale range" do
      refute AdminGate.tailscale_ip?({0xFD00, 0, 0, 0, 0, 0, 0, 1})
      refute AdminGate.tailscale_ip?({0x2001, 0xDB8, 0, 0, 0, 0, 0, 1})
    end
  end

  describe "call/2 gate" do
    setup do
      # Swap admin_emails for the test, restore on exit.
      old = Application.get_env(:saas_starter, :admin_emails, [])
      on_exit(fn -> Application.put_env(:saas_starter, :admin_emails, old) end)
      :ok
    end

    # `log_in_user/2` from ConnCase puts the session token but doesn't
    # run the UserAuth plug chain, so `current_scope` isn't assigned.
    # AdminGate expects that assign; fake it directly for these tests.
    defp with_scope(conn, user) do
      Plug.Conn.assign(conn, :current_scope, SaasStarter.Accounts.Scope.for_user(user))
    end

    test "404s when request is not from Tailscale", %{conn: conn} do
      user = user_fixture()
      Application.put_env(:saas_starter, :admin_emails, [user.email])

      conn =
        conn
        |> with_scope(user)
        |> Map.put(:remote_ip, @public_v4)
        |> AdminGate.call([])

      assert conn.status == 404
      assert conn.halted
    end

    test "404s when user is not authenticated", %{conn: conn} do
      conn =
        conn
        |> Map.put(:remote_ip, @tailscale_v4)
        |> AdminGate.call([])

      assert conn.status == 404
      assert conn.halted
    end

    test "404s when email is not on the allowlist", %{conn: conn} do
      user = user_fixture()
      Application.put_env(:saas_starter, :admin_emails, ["someone-else@example.com"])

      conn =
        conn
        |> with_scope(user)
        |> Map.put(:remote_ip, @tailscale_v4)
        |> AdminGate.call([])

      assert conn.status == 404
      assert conn.halted
    end

    test "passes through when all three gates are satisfied", %{conn: conn} do
      user = user_fixture()
      Application.put_env(:saas_starter, :admin_emails, [user.email])

      conn =
        conn
        |> with_scope(user)
        |> Map.put(:remote_ip, @tailscale_v4)
        |> AdminGate.call([])

      refute conn.halted
      refute conn.status
    end
  end
end
