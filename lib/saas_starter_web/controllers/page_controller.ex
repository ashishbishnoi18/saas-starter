defmodule SaasStarterWeb.PageController do
  use SaasStarterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
