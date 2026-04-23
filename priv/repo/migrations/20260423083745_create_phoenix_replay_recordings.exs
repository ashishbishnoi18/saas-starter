defmodule SaasStarter.Repo.Migrations.CreatePhoenixReplayRecordings do
  use Ecto.Migration

  def change do
    create table(:phoenix_replay_recordings, primary_key: false) do
      add :id, :string, primary_key: true
      add :view, :string, null: false
      add :connected_at, :bigint, null: false
      add :event_count, :integer, null: false, default: 0
      add :data, :binary, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
