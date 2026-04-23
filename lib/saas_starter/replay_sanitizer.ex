defmodule SaasStarter.ReplaySanitizer do
  @moduledoc """
  PII sanitizer for `:phoenix_replay` recordings.

  Wraps `PhoenixReplay.Sanitizer` (which already drops internal LiveView
  keys and standard sensitive fields like `:password`, `:token`) and adds
  project-specific redactions: email, mobile, national IDs. Called by the
  recorder for every mount, event, and assign delta before serialization.

  Implements the `sanitize_assigns/1` and `sanitize_delta/2` callbacks
  expected by `PhoenixReplay.Recorder`.
  """

  @extra_sensitive_keys ~w(
    email email_address
    mobile_number phone phone_number
    aadhaar pan passport ssn
    hashed_password magic_link_token access_token refresh_token
  )a

  @redacted "[REDACTED]"

  def sanitize_assigns(assigns) when is_map(assigns) do
    assigns
    |> PhoenixReplay.Sanitizer.sanitize_assigns()
    |> redact_extras()
  end

  def sanitize_delta(changed, assigns) when is_map(changed) and is_map(assigns) do
    changed
    |> PhoenixReplay.Sanitizer.sanitize_delta(assigns)
    |> redact_extras()
  end

  defp redact_extras(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      if key in @extra_sensitive_keys do
        {key, @redacted}
      else
        {key, redact_nested(value)}
      end
    end)
  end

  defp redact_nested(%{__struct__: _} = struct), do: struct
  defp redact_nested(map) when is_map(map), do: redact_extras(map)
  defp redact_nested(list) when is_list(list), do: Enum.map(list, &redact_nested/1)
  defp redact_nested(other), do: other
end
