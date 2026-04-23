defmodule SaasStarter.HTTPTest do
  use ExUnit.Case, async: true

  alias SaasStarter.HTTP

  setup do
    # Stub the Req network layer so the test never hits the wire.
    Req.Test.stub(:global, fn conn ->
      case conn.request_path do
        "/ok" -> Req.Test.json(conn, %{"ok" => true})
        "/boom" -> Plug.Conn.resp(conn, 500, "boom")
      end
    end)

    # Capture telemetry events for the duration of the test.
    handler_id = "http-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach(
      handler_id,
      [:saas_starter, :http, :request],
      fn _event, measurements, metadata, _ ->
        send(parent, {:http_event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "get/2" do
    test "returns {:ok, resp} and emits a telemetry event on 200" do
      assert {:ok, %Req.Response{status: 200}} =
               HTTP.get("http://example.test/ok", plug: {Req.Test, :global})

      assert_receive {:http_event, %{duration_ms: ms}, %{method: :get, status: 200, url: url}}
      assert is_integer(ms) and ms >= 0
      assert url =~ "/ok"
    end

    test "still emits an event on non-2xx" do
      assert {:ok, %Req.Response{status: 500}} =
               HTTP.get("http://example.test/boom", plug: {Req.Test, :global}, retry: false)

      assert_receive {:http_event, _measurements, %{status: 500}}
    end
  end
end
