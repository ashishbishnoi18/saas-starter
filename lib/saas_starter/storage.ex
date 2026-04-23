defmodule SaasStarter.Storage do
  @moduledoc """
  Object storage backed by Cloudflare R2 (S3-compatible), with a Cloudflare
  CDN in front for public-readable assets.

  ## Two URL flavors

  - **Public CDN URL** — `public_url/1`. Used when the bucket is fronted
    by a Cloudflare CDN zone and the object was uploaded with public
    access. No signing, cached edge-side, cheap.
  - **Presigned URL** — `presigned_url/3`. Short-lived signed URL for
    private objects. Default expiry 1 hour.

  All three operations (`put/3`, `delete/1`, `presigned_url/3`) emit
  a `[:saas_starter, :storage, :request]` telemetry span with
  measurements `%{duration_ms: n}` and metadata `%{op: atom, key: string,
  status: atom}` so object-storage I/O is observable alongside other
  telemetry.

  ## Configuration

  Bucket and CDN URL come from `config :saas_starter, :storage`. R2
  credentials + endpoint come from the `:ex_aws` config. See
  `config/runtime.exs`.
  """

  require Logger

  alias ExAws.S3

  @type key :: String.t()
  @type opts :: keyword()

  @doc """
  Upload `body` to `key`. `body` may be a binary or an enumerable that
  yields binaries (streaming uploads for large files).

  ### Options

    * `:content_type` — MIME type (default `"application/octet-stream"`)
    * `:acl` — `"public-read"` for CDN-fronted public assets, omit or
      `"private"` for auth-gated assets. Default `"private"`.
    * `:cache_control` — `Cache-Control` header. Public assets typically
      want `"public, max-age=31536000, immutable"`.
  """
  @spec put(key(), binary() | Enumerable.t(), opts()) ::
          {:ok, term()} | {:error, term()}
  def put(key, body, opts \\ []) when is_binary(key) do
    headers = [
      {"content-type", Keyword.get(opts, :content_type, "application/octet-stream")}
    ]

    headers =
      case opts[:cache_control] do
        nil -> headers
        cc -> [{"cache-control", cc} | headers]
      end

    s3_opts = []
    s3_opts = if acl = opts[:acl], do: Keyword.put(s3_opts, :acl, acl), else: s3_opts

    with_telemetry(:put, key, fn ->
      bucket()
      |> S3.put_object(key, body, Keyword.put(s3_opts, :headers, headers))
      |> ExAws.request()
    end)
  end

  @doc """
  Delete an object. Returns `:ok` whether or not the object existed
  (R2, like S3, returns 204 in both cases).
  """
  @spec delete(key()) :: :ok | {:error, term()}
  def delete(key) when is_binary(key) do
    case with_telemetry(:delete, key, fn ->
           bucket() |> S3.delete_object(key) |> ExAws.request()
         end) do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Generate a presigned GET URL. Caller can hand the URL to a browser for
  direct download without routing bytes through the app.

  `expires_in_seconds` defaults to 3600 (1h). Max is 7 days per the S3
  v4 signing spec.
  """
  @spec presigned_url(key(), :get | :put, pos_integer()) ::
          {:ok, String.t()} | {:error, term()}
  def presigned_url(key, method \\ :get, expires_in_seconds \\ 3600)
      when is_binary(key) and method in [:get, :put] do
    with_telemetry(:presigned, key, fn ->
      :s3
      |> ExAws.Config.new()
      |> S3.presigned_url(method, bucket(), key, expires_in: expires_in_seconds)
    end)
  end

  @doc """
  Public CDN URL for a key. Requires `:public_cdn_base_url` to be
  configured. Returns `{:error, :no_cdn}` otherwise — fall back to
  `presigned_url/3` when the asset isn't CDN-backed.
  """
  @spec public_url(key()) :: {:ok, String.t()} | {:error, :no_cdn}
  def public_url(key) when is_binary(key) do
    case Application.get_env(:saas_starter, :storage)[:public_cdn_base_url] do
      nil -> {:error, :no_cdn}
      "" -> {:error, :no_cdn}
      base -> {:ok, String.trim_trailing(base, "/") <> "/" <> URI.encode(key)}
    end
  end

  defp bucket do
    Application.get_env(:saas_starter, :storage)[:bucket] ||
      raise "config :saas_starter, :storage, :bucket is not set"
  end

  defp with_telemetry(op, key, fun) do
    start = System.monotonic_time()
    result = fun.()
    duration_ms = System.convert_time_unit(System.monotonic_time() - start, :native, :millisecond)

    status =
      case result do
        {:ok, _} -> :ok
        :ok -> :ok
        {:error, _} -> :error
      end

    :telemetry.execute(
      [:saas_starter, :storage, :request],
      %{duration_ms: duration_ms},
      %{op: op, key: key, status: status}
    )

    result
  end
end
