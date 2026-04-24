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

  describe "bucket/0" do
    test "raises a helpful error when no bucket is configured" do
      Application.put_env(:saas_starter, :storage, bucket: nil)

      assert_raise RuntimeError, ~r/:bucket is not set/, fn ->
        # Indirect: public_url doesn't need bucket, so force a delete
        # which reads it. We only assert the raise path — actually
        # calling R2 would need credentials + connectivity, which is
        # integration territory (out of scope for unit tests).
        Storage.delete("irrelevant.png")
      end
    end
  end
end
