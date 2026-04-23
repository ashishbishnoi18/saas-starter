defmodule SaasStarterWeb.Plugs.AdminGate do
  @moduledoc """
  Gate for admin routes. Enforces three independent checks:

    1. **Tailscale-only access.** `conn.remote_ip` must fall within the
       Tailscale CGNAT v4 range (`100.64.0.0/10`) or the Tailscale v6
       range (`fd7a:115c:a1e0::/48`). Public internet requests are
       rejected with 404 — we don't reveal the admin surface exists.
    2. **Authenticated.** `conn.assigns.current_scope.user` must be set.
    3. **Allowlisted email.** The user's email must be in
       `Application.get_env(:saas_starter, :admin_emails)`.

  Behind a reverse proxy? Make sure Phoenix sees the real client IP:
  nginx should set `X-Forwarded-For` and you should add a plug like
  `RemoteIp` (not in v0.1) or bind Phoenix directly to the Tailscale
  interface so the proxy is out of the picture.

  ## Use

      pipeline :admin do
        plug SaasStarterWeb.Plugs.AdminGate
      end

  Configure allowlist in `config/runtime.exs`:

      config :saas_starter, :admin_emails, ["you@example.com"]
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with :ok <- check_tailscale(conn),
         :ok <- check_authenticated(conn),
         :ok <- check_allowlist(conn) do
      conn
    else
      {:deny, _reason} ->
        conn
        |> send_resp(404, "")
        |> halt()
    end
  end

  @doc """
  Returns true if the given IP tuple belongs to a Tailscale-assigned range.

  - IPv4: CGNAT `100.64.0.0/10` — second octet 64..127 with first = 100.
  - IPv6: ULA `fd7a:115c:a1e0::/48` — first three hextets fixed.

  Exposed for testing and for reuse if another plug (e.g. a dev-only
  LiveDashboard gate) wants the same rule.
  """
  def tailscale_ip?({100, b, _, _}) when b >= 64 and b <= 127, do: true
  def tailscale_ip?({0xFD7A, 0x115C, 0xA1E0, _, _, _, _, _}), do: true
  def tailscale_ip?(_), do: false

  defp check_tailscale(conn) do
    if tailscale_ip?(conn.remote_ip), do: :ok, else: {:deny, :not_tailscale}
  end

  defp check_authenticated(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{email: email}} when is_binary(email) -> :ok
      _ -> {:deny, :unauthenticated}
    end
  end

  defp check_allowlist(conn) do
    email = conn.assigns.current_scope.user.email
    allowlist = Application.get_env(:saas_starter, :admin_emails, [])

    if email in allowlist, do: :ok, else: {:deny, :not_allowlisted}
  end
end
