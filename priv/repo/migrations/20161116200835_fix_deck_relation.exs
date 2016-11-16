defmodule Popura.Repo.Migrations.FixDeckRelation do
  use Ecto.Migration

  @moduledoc """
  This migration splits `deck_cards` into two separate many-to-many relations.
  This is primarily done to achieve better cascading delete behavior, the new
  schema works as follows:

  Lobbies have some number of cards through a relation table: 

      lobbies_cards
      -------------
      card_id  :: integer
      lobby_id :: integer
      tag      :: string

  The tag is a discriminant which allows the lobby to arbitrarily move cards
  between any arbitrary number of named piles. It will be indexed for fast
  search performance.

  Likewise players have some number of cards through a similar relation table:

      players_cards
      -------------
      card_id   :: integer
      player_id :: integer

  There is no need for a discriminator, as the cards leave the player's hand
  once submitted (i.e they are deleted.)

  This approach has the advantage that the "deck" relations now have the foreign
  key constraint, i.e: they are now children of their respective parent tables:
  lobbies, and players.

  This means that when lobbies & players are removed at the end of the game, a
  cascading delete will clean up all their piles of cards.
  """

  def change do
    drop table(:deck_cards)

    create table(:lobbies_cards) do
      add :lobby_id, references(:lobbies, on_delete: :delete_all)
      add :card_id,  references(:cards,   on_delete: :delete_all)
      add :tag, :string
    end

    # TODO: probably not ideal indices ...
    # maybe lobby & tag should go together?
    create index(:lobbies_cards, [:lobby_id])
    create index(:lobbies_cards, [:card_id])
    create index(:lobbies_cards, [:tag])

    create table(:players_cards) do
      add :player_id, references(:players, on_delete: :delete_all)
      add :card_id,   references(:cards,   on_delete: :delete_all)
    end

    create index(:players_cards, [:player_id])
    create index(:players_cards, [:card_id])
  end
end
