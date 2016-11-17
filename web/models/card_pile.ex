defmodule Popura.CardPile do
  use Popura.Web, :model

  schema "cards_piles" do
    field :tag, :string

    belongs_to :card,   Popura.Card
    belongs_to :player, Popura.Player
    belongs_to :lobby,  Popura.Lobby
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:tag])
    |> validate_required([:tag])
  end
end
