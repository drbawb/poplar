defmodule Popura.Repo.Migrations.RemergerateCards do
  use Ecto.Migration

  @doc "memes were a mistake"
  def up do
    drop table(:lobbies_cards)
    drop table(:players_cards)
  end

  def down do
    create table(:lobbies_cards) do
      add :lobby_id, references(:lobbies, on_delete: :delete_all)
      add :card_id,  references(:cards,   on_delete: :delete_all)
      add :tag, :string
    end

    create table(:players_cards) do
      add :player_id, references(:players, on_delete: :delete_all)
      add :card_id,   references(:cards,   on_delete: :delete_all)
    end
  end
end
