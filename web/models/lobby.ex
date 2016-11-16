defmodule Popura.Lobby do
  use Popura.Web, :model

  @black_deck "black"
  @white_deck "white"
  @black_discard "black_discard"
  @white_discard "white_discard"

  schema "lobbies" do
    field :name, :string
    field :password, :string
    field :owner_id, Ecto.UUID
    field :serv_lock, :boolean

    has_many :cards, Popura.LobbyCard, on_delete: :delete_all
    has_many :players, Popura.Player,  on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :password, :owner_id, :serv_lock])
    |> validate_required([:name, :password, :owner_id])
  end

  def with_decks(query) do
    from l in query,
    left_join: c in assoc(l, :cards),
    preload: [cards: c]
  end

  def count_players(query) do
    from l in query,
    join: p in assoc(l, :players),
    select: count(p.id)
  end

  def black_deck,    do: @black_deck
  def black_discard, do: @black_discard
  def white_deck,    do: @white_deck
  def white_discard, do: @white_discard
end
