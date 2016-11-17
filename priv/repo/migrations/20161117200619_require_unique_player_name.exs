defmodule Popura.Repo.Migrations.RequireUniquePlayerName do
  use Ecto.Migration

  def change do
    create unique_index(:players, [:lobby_id, :name])
  end
end
