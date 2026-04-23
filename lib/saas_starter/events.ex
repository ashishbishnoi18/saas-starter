defmodule SaasStarter.Events do
  @moduledoc """
  Durable product analytics. One row per event in `product_events`.

  This is the **load-bearing** analytics layer — session replay via
  `:phoenix_replay` is additive and may change. Everything important goes
  through `track/3`. Funnels, retention, and activation are plain SQL.

  Writes are sync by default; wrap in a `Task` at the call site if a call
  path is latency-sensitive and the event is non-critical.
  """

  import Ecto.Query, warn: false

  alias SaasStarter.Repo
  alias SaasStarter.Events.Event
  alias SaasStarter.Accounts.User

  @doc """
  Record a product event.

  ## Examples

      iex> SaasStarter.Events.track(user, "auth.login", %{provider: "google"})
      {:ok, %Event{}}

      iex> SaasStarter.Events.track(nil, "page.view", %{path: "/"})
      {:ok, %Event{}}

  """
  @spec track(User.t() | nil, String.t(), map()) ::
          {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def track(user, event_name, metadata \\ %{})
      when is_binary(event_name) and is_map(metadata) do
    %Event{}
    |> Event.changeset(%{
      event_name: event_name,
      metadata: metadata,
      user_id: user && user.id
    })
    |> Repo.insert()
  end

  @doc "Returns the total number of events matching `event_name`."
  @spec count(String.t()) :: non_neg_integer()
  def count(event_name) when is_binary(event_name) do
    Repo.aggregate(from(e in Event, where: e.event_name == ^event_name), :count, :id)
  end

  @doc "List the most recent `limit` events (newest first)."
  @spec list_recent(pos_integer()) :: [Event.t()]
  def list_recent(limit \\ 100) when is_integer(limit) and limit > 0 do
    Event
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
