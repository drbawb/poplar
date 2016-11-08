defmodule Popura.Repo.Migrations.CreateLobby do
  use Ecto.Migration

  def change do
    create table(:lobbies) do
      add :name, :string
      add :password, :string
      add :owner_id, :uuid

      timestamps()
    end

  end
end
