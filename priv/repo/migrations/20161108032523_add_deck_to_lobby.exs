defmodule Popura.Repo.Migrations.AddDeckToLobby do
  use Ecto.Migration

  def change do
    alter table(:lobbies) do
      add :black_deck_id,    references(:decks)
      add :black_discard_id, references(:decks)
      add :white_deck_id,    references(:decks)
      add :white_discard_id, references(:decks)
    end
  end
end
