defmodule SaasStarter.Events.Event do
  @moduledoc """
  A product event — one row per meaningful user action. The durable analytics
  log that outlives any session-replay backend. Query with plain SQL for
  funnels, retention, and activation metrics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias SaasStarter.Accounts.User

  schema "product_events" do
    field :event_name, :string
    field :metadata, :map, default: %{}
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :metadata, :user_id])
    |> validate_required([:event_name])
    |> validate_length(:event_name, max: 120)
  end
end
