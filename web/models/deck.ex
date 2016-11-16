defmodule Popura.Deck do
  use Popura.Web, :model

  schema "decks" do
    field :name, :string

    has_many :cards, Popura.Card, on_delete: :delete_all
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
