defmodule SaasStarter.ReplaySanitizerTest do
  use ExUnit.Case, async: true

  alias SaasStarter.ReplaySanitizer

  @redacted "[REDACTED]"

  describe "sanitize_assigns/1" do
    test "redacts known PII keys" do
      input = %{
        email: "user@example.com",
        mobile_number: "+15551234567",
        aadhaar: "1234-5678-9012",
        current_user: %{id: 1, name: "Alice"}
      }

      assert %{email: @redacted, mobile_number: @redacted, aadhaar: @redacted} =
               ReplaySanitizer.sanitize_assigns(input)
    end

    test "drops internal LiveView keys (via underlying sanitizer)" do
      input = %{
        __changed__: %{name: true},
        flash: %{"info" => "hi"},
        name: "Alice"
      }

      result = ReplaySanitizer.sanitize_assigns(input)

      refute Map.has_key?(result, :__changed__)
      refute Map.has_key?(result, :flash)
      assert result.name == "Alice"
    end

    test "preserves non-sensitive keys as-is" do
      input = %{title: "Dashboard", count: 42}
      assert ReplaySanitizer.sanitize_assigns(input) == input
    end

    test "redacts the default sensitive keys from PhoenixReplay.Sanitizer too" do
      input = %{password: "secret123", token: "abc", current_password: "old"}
      result = ReplaySanitizer.sanitize_assigns(input)

      refute Map.has_key?(result, :password)
      refute Map.has_key?(result, :token)
      refute Map.has_key?(result, :current_password)
    end
  end

  describe "sanitize_delta/2" do
    test "sanitizes only changed keys, respecting PII list" do
      changed = %{email: true, name: true}
      assigns = %{email: "user@example.com", name: "Alice", password: "secret"}

      result = ReplaySanitizer.sanitize_delta(changed, assigns)

      assert result.email == @redacted
      assert result.name == "Alice"
      refute Map.has_key?(result, :password)
    end
  end
end
