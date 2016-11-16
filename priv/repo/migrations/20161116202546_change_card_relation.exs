defmodule Popura.Repo.Migrations.ChangeCardRelation do
  use Ecto.Migration

  def change do
    alter table(:decks) do
      remove :is_generated
    end

    alter table(:cards) do
      add :deck_id, references(:decks, on_delete: :delete_all)
    end

    create index(:cards, [:deck_id])
  end
end
