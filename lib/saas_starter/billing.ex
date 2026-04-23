defmodule SaasStarter.Billing do
  @moduledoc """
  Billing port. v0.1 intentionally ships a no-op `Stub` implementation —
  `stripity_stripe` is declared as a dependency so a future recipe can
  activate it without changing `mix.exs`.

  Activation recipe: `RECIPES/31-add-stripe-billing.md`.

  The behaviour exists so callers can program against `SaasStarter.Billing`
  and swap implementations (Stub for dev/test, real Stripe client for prod)
  via Application config:

      config :saas_starter, :billing, SaasStarter.Billing.Stub
  """

  @callback charge(params :: map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Returns the configured billing implementation. Defaults to Stub.
  """
  @spec impl() :: module()
  def impl, do: Application.get_env(:saas_starter, :billing, SaasStarter.Billing.Stub)

  @doc "Delegates to the configured implementation's `charge/1`."
  @spec charge(map()) :: {:ok, term()} | {:error, term()}
  def charge(params) when is_map(params), do: impl().charge(params)
end
