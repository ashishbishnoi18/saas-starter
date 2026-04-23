defmodule SaasStarter.Billing.Stub do
  @moduledoc """
  No-op billing implementation for v0.1. Returns `{:error, :not_configured}`
  on every call so tests can assert "no charges attempted" without mocks.
  """
  @behaviour SaasStarter.Billing

  @impl true
  def charge(_params), do: {:error, :not_configured}
end
