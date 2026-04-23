defmodule SaasStarter.HTTP do
  @moduledoc """
  Thin wrapper around `Req` that emits `:telemetry` spans so outgoing HTTP
  calls land in the `product_events` analytics log the same way LiveView
  events do.

  All network I/O in the app **must** go through this module. Direct `Req`,
  `HTTPoison`, or `Tesla` calls are forbidden (see CONVENTIONS.md).

  ## Example

      iex> SaasStarter.HTTP.get("https://httpbin.org/json")
      {:ok, %Req.Response{status: 200, body: %{...}}}

  The telemetry event name is `[:saas_starter, :http, :request]`. Measurements
  include `:duration_ms`. Metadata includes `:method`, `:url`, `:status` (on
  success), `:error` (on failure).
  """

  @doc "Issue a GET. Options are passed through to Req."
  @spec get(String.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
  def get(url, opts \\ []), do: request(:get, url, opts)

  @doc "Issue a POST with a JSON body."
  @spec post(String.t(), term(), keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
  def post(url, body, opts \\ []), do: request(:post, url, Keyword.put(opts, :json, body))

  defp request(method, url, opts) do
    start = System.monotonic_time()

    case Req.request([method: method, url: url] ++ opts) do
      {:ok, %Req.Response{status: status} = resp} ->
        emit(method, url, %{status: status}, start)
        {:ok, resp}

      {:error, reason} ->
        emit(method, url, %{error: inspect(reason)}, start)
        {:error, reason}
    end
  end

  defp emit(method, url, extra, start) do
    duration_ms =
      (System.monotonic_time() - start)
      |> System.convert_time_unit(:native, :millisecond)

    :telemetry.execute(
      [:saas_starter, :http, :request],
      %{duration_ms: duration_ms},
      Map.merge(%{method: method, url: url}, extra)
    )
  end
end
