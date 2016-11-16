defmodule Popura.Card do
  use Popura.Web, :model

  schema "cards" do
    field :body, :string
    field :slots, :integer

    belongs_to :deck, Popura.Deck

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:body, :slots])
    |> validate_required([:body, :slots])
  end
end
