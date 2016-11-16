defmodule Popura.Deck do
  use Popura.Web, :model

  schema "decks" do
    field :name, :string
    field :is_generated, :boolean
    many_to_many(:cards, Popura.Card, join_through: Popura.DeckCard)
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :is_generated])
    |> validate_required([:name])
  end
end
