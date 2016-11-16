defmodule Popura.Repo.Migrations.AddSysFlagToDeck do
  use Ecto.Migration

  def change do
    alter table(:decks) do
      add :is_generated, :boolean, default: false
    end
  end
end
