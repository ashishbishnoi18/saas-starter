defmodule SaasStarterWeb.HomeLive do
  @moduledoc """
  Public landing page. No auth required. Replaces the default Phoenix
  marketing splash. Kept deliberately skeletal so a project cloning this
  starter has a blank canvas.
  """
  use SaasStarterWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="home-root" class="mx-auto max-w-2xl text-center space-y-8 py-16">
        <.header>
          <p>SaasStarter</p>
          <:subtitle>
            A Phoenix + LiveView SaaS starter template.
          </:subtitle>
        </.header>

        <div class="flex items-center justify-center gap-3">
          <%= if @current_scope do %>
            <.link navigate={~p"/dashboard"} class="btn btn-primary" id="cta-dashboard">
              Go to dashboard
            </.link>
          <% else %>
            <.link navigate={~p"/users/log-in"} class="btn btn-primary" id="cta-login">
              Log in
            </.link>
          <% end %>
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
