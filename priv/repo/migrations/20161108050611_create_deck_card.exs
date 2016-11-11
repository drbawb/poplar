defmodule Popura.Repo.Migrations.CreateDeckCard do
  use Ecto.Migration

  def change do
    create table(:deck_cards) do
      add :deck_id, references(:decks, on_delete: :delete_all)
      add :card_id, references(:cards, on_delete: :delete_all)
    end

    create index(:deck_cards, [:deck_id])
    create index(:deck_cards, [:card_id])
  end
end
