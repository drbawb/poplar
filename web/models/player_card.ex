defmodule Popura.PlayerCard do
  use Popura.Web, :model

  schema "players_cards" do
    belongs_to :card,   Popura.Card
    belongs_to :player, Popura.Player
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:card_id, :player_id])
    |> validate_required([:card_id, :player_id])
  end
end
