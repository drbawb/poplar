defmodule Popura.DeckCard do
  use Popura.Web, :model

  schema "deck_cards" do
    belongs_to :card, Popura.Card
    belongs_to :deck, Popura.Deck
  end


  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:card_id, :deck_id])
    |> validate_required([:card_id, :deck_id])
  end

end
