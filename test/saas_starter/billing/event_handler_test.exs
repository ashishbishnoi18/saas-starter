defmodule SaasStarter.Billing.EventHandlerTest do
  use ExUnit.Case, async: true

  alias SaasStarter.Billing.EventHandler

  describe "handle/1" do
    test "returns :ok for a plain event map" do
      assert :ok = EventHandler.handle(%{type: "checkout.session.completed", data: %{}})
    end

    test "returns :ok even for unrecognized shapes (default no-op)" do
      assert :ok = EventHandler.handle(%{unexpected: :shape})
      assert :ok = EventHandler.handle(nil)
      assert :ok = EventHandler.handle("string")
    end
  end
end
