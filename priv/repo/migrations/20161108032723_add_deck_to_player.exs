defmodule Popura.Repo.Migrations.AddDeckToPlayer do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :hand_id, references(:decks)
    end
  end
end
