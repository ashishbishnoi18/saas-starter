defmodule SaasStarterWeb.DashboardLive do
  @moduledoc """
  Authenticated landing after login. Accessible only through the
  `:require_authenticated_user` live_session, so `@current_scope` is
  always present.

  Skeleton by design — the next AI session builds the actual dashboard
  features here (or replaces this module per the project's needs).
  """
  use SaasStarterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="dashboard-root" class="mx-auto max-w-2xl space-y-6 py-12">
        <.header>
          <p>Dashboard</p>
          <:subtitle>
            You're logged in as <span id="dashboard-email">{@current_scope.user.email}</span>.
          </:subtitle>
        </.header>

        <div class="card bg-base-200">
          <div class="card-body">
            <p class="text-base-content/70">
              Build your app's logged-in surface starting here. This file lives
              at <code>lib/saas_starter_web/live/dashboard_live.ex</code>.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
