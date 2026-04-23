defmodule SaasStarter.Billing.LiveTest do
  use ExUnit.Case, async: true

  alias SaasStarter.Billing.Live

  describe "charge/1 input validation" do
    test "returns :price_id_required when price_id is missing" do
      assert {:error, :price_id_required} = Live.charge(%{})
      assert {:error, :price_id_required} = Live.charge(%{success_url: "x", cancel_url: "y"})
    end

    test "raises when success_url is missing (contract violation)" do
      assert_raise ArgumentError, ~r/success_url/, fn ->
        Live.charge(%{price_id: "price_x", cancel_url: "y"})
      end
    end

    test "raises when cancel_url is missing" do
      assert_raise ArgumentError, ~r/cancel_url/, fn ->
        Live.charge(%{price_id: "price_x", success_url: "y"})
      end
    end
  end
end
