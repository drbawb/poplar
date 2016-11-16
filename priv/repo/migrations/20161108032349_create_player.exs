defmodule Popura.Repo.Migrations.CreatePlayer do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :string
      add :user_id, :uuid
      add :lobby_id, references(:lobbies, on_delete: :delete_all)

      timestamps()
    end
    create index(:players, [:lobby_id])

  end
end
