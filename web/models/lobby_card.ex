defmodule Popura.LobbyCard do
  use Popura.Web, :model

  schema "lobbies_cards" do
    field :tag, :string
    belongs_to :card,  Popura.Card
    belongs_to :lobby, Popura.Lobby
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:card_id, :lobby_id, :tag])
    |> validate_required([:card_id, :lobby_id, :tag])
  end
end
