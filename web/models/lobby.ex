defmodule Popura.Lobby do
  use Popura.Web, :model

  schema "lobbies" do
    field :name, :string
    field :password, :string
    field :owner_id, Ecto.UUID
    field :serv_lock, :boolean

    has_many :players, Popura.Player

    belongs_to :black_deck,    Popura.Deck
    belongs_to :white_deck,    Popura.Deck
    belongs_to :black_discard, Popura.Deck
    belongs_to :white_discard, Popura.Deck

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :password, :owner_id])
    |> validate_required([:name, :password, :owner_id])
  end
end
