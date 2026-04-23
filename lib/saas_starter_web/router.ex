defmodule SaasStarterWeb.Router do
  use SaasStarterWeb, :router

  import SaasStarterWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SaasStarterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SaasStarterWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{SaasStarterWeb.UserAuth, :mount_current_scope}, PhoenixReplay.Recorder] do
      live "/", HomeLive, :home
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SaasStarterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:saas_starter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SaasStarterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SaasStarterWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SaasStarterWeb.UserAuth, :require_authenticated}, PhoenixReplay.Recorder] do
      live "/dashboard", DashboardLive, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SaasStarterWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SaasStarterWeb.UserAuth, :mount_current_scope}, PhoenixReplay.Recorder] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## OAuth (Ueberauth) — Google. See lib/saas_starter_web/controllers/oauth_controller.ex.
  scope "/auth", SaasStarterWeb do
    pipe_through :browser

    get "/:provider", OAuthController, :request
    get "/:provider/callback", OAuthController, :callback
  end

  ## Admin routes — gated by Tailscale + email allowlist.
  ##
  ## Hang actual admin pages off the :admin live_session below. The
  ## starter ships the gate primitive only; each app writes its own
  ## admin surface (user management, impersonation, billing overrides,
  ## etc.) since those vary per-app.
  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SaasStarterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug SaasStarterWeb.Plugs.AdminGate
  end

  scope "/admin", SaasStarterWeb.Admin do
    pipe_through :admin

    live_session :admin,
      on_mount: [{SaasStarterWeb.UserAuth, :require_authenticated}, PhoenixReplay.Recorder] do
      # Add your app-specific admin pages here, e.g.:
      #   live "/", DashboardLive, :index
      #   live "/users", UsersLive, :index
    end
  end
end
