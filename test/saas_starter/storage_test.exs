defmodule SaasStarter.StorageTest do
  use ExUnit.Case, async: false

  alias SaasStarter.Storage

  setup do
    # Ensure every test sees a clean :storage config and restore on exit.
    prev = Application.get_env(:saas_starter, :storage, [])
    on_exit(fn -> Application.put_env(:saas_starter, :storage, prev) end)
    :ok
  end

  describe "public_url/1" do
    test "returns a URL when public_cdn_base_url is set" do
      Application.put_env(:saas_starter, :storage,
        bucket: "b",
        public_cdn_base_url: "https://cdn.example.com"
      )

      assert {:ok, "https://cdn.example.com/path/to/file.png"} =
               Storage.public_url("path/to/file.png")
    end

    test "strips a trailing slash from the base URL" do
      Application.put_env(:saas_starter, :storage,
        bucket: "b",
        public_cdn_base_url: "https://cdn.example.com/"
      )

      assert {:ok, "https://cdn.example.com/a.png"} = Storage.public_url("a.png")
    end

    test "URL-encodes the key" do
      Application.put_env(:saas_starter, :storage,
        bucket: "b",
        public_cdn_base_url: "https://cdn.example.com"
      )

      assert {:ok, url} = Storage.public_url("user uploads/file name.png")
      assert url =~ "user%20uploads/file%20name.png"
    end

    test "returns :no_cdn when public_cdn_base_url is not configured" do
      Application.put_env(:saas_starter, :storage, bucket: "b", public_cdn_base_url: nil)
      assert Storage.public_url("x.png") == {:error, :no_cdn}

      Application.put_env(:saas_starter, :storage, bucket: "b", public_cdn_base_url: "")
      assert Storage.public_url("x.png") == {:error, :no_cdn}
    end
  end

  describe "telemetry" do
    setup do
      Application.put_env(:saas_starter, :storage, bucket: "testbucket")

      handler_id = "storage-test-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:saas_starter, :storage, :request],
        fn _event, measurements, metadata, _ ->
          send(parent, {:storage_event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      :ok
    end

    @tag :capture_log
    test "emits an event on delete (even when R2 is unreachable)" do
      # No R2 credentials configured; the request will fail. We only
      # assert the telemetry span is emitted regardless of outcome.
      _ = Storage.delete("does/not/matter.png")

      assert_receive {:storage_event, %{duration_ms: ms}, %{op: :delete, key: key, status: status}},
                     2_000

      assert is_integer(ms) and ms >= 0
      assert key == "does/not/matter.png"
      assert status in [:ok, :error]
    end
  end
end
