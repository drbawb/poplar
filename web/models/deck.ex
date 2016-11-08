defmodule Popura.Deck do
  use Popura.Web, :model

  schema "decks" do
    field :name, :string

    many_to_many(:cards, Popura.Card, join_through: "deck_cards")

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
