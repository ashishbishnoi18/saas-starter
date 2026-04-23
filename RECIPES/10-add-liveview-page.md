# Add a LiveView page

## Pattern

1. Create `lib/saas_starter_web/live/<feature>_live.ex`.
2. Give every meaningful element a stable DOM ID (tests assert on these).
3. Add a `live` route inside the correct `live_session` in `router.ex`.
4. Write `test/saas_starter_web/live/<feature>_live_test.exs`.

## Module skeleton

```elixir
defmodule SaasStarterWeb.FeatureLive do
  @moduledoc "What this page is for, in one sentence."
  use SaasStarterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="feature-root" class="...">
        <.header>
          <p>Title</p>
        </.header>
        <!-- content -->
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}
end
```

## Routing

Pick the right `live_session`:

- **Public** (signed-out allowed): `:public` scope
- **Authenticated only**: `:require_authenticated_user` scope — gets
  `@current_scope.user`
- **Re-auth (sudo mode)**: `:require_authenticated_user` with a
  `require_sudo_mode` on_mount (not wired in v0.1; add when needed)

Every `live_session` already includes `PhoenixReplay.Recorder` — don't
remove it.

## Test skeleton

```elixir
defmodule SaasStarterWeb.FeatureLiveTest do
  use SaasStarterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import SaasStarter.AccountsFixtures

  test "renders", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/feature")
    assert has_element?(view, "#feature-root")
  end

  test "requires auth", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/feature")
    assert path =~ "/users/log-in"
  end
end
```

Use `log_in_user(conn, user_fixture())` from `ConnCase` to sign in.

## Analytics

LiveView `mount` and `handle_event` are already tracked to `product_events`
automatically (see `SaasStarter.Events.TelemetryHandler`). If you want to
record a custom application event:

```elixir
SaasStarter.Events.track(socket.assigns.current_scope.user, "feature.clicked", %{action: "foo"})
```

## Forbidden

- Hard-coded HTML strings in tests — use `has_element?`
- `live_patch` / `live_redirect` (deprecated) — use `push_patch` / `push_navigate`
- Raw `<script>` tags in HEEx — use colocated hooks or `assets/js/`
