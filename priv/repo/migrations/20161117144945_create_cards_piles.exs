defmodule Popura.Repo.Migrations.CreateCardsPiles do
  use Ecto.Migration

  def change do
    create table(:cards_piles) do
      add :tag, :string
      add :card_id,   references(:cards, on_delete: :delete_all)
      add :lobby_id,  references(:lobbies, on_delete: :delete_all)
      add :player_id, references(:players, on_delete: :delete_all)
    end
  end
end
