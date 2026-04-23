defmodule SaasStarter.BillingTest do
  use ExUnit.Case, async: true

  alias SaasStarter.Billing

  describe "Billing (stub impl)" do
    test "defaults to Stub when :billing is not configured" do
      assert Billing.impl() == SaasStarter.Billing.Stub
    end

    test "charge/1 returns :not_configured on the stub" do
      assert {:error, :not_configured} = Billing.charge(%{amount: 100, currency: "usd"})
    end
  end
end
