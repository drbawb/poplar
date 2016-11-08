defmodule Popura.Repo.Migrations.AddLockToLobby do
  use Ecto.Migration

  def change do
    alter table(:lobbies) do
      add :serv_lock, :boolean, default: false
    end
  end
end
