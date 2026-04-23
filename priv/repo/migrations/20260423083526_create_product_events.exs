defmodule SaasStarter.Repo.Migrations.CreateProductEvents do
  use Ecto.Migration

  def change do
    create table(:product_events) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :event_name, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:product_events, [:event_name])
    create index(:product_events, [:inserted_at])
    create index(:product_events, [:user_id])
  end
end
