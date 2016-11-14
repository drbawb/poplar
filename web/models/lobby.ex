defmodule Popura.Lobby do
  use Popura.Web, :model

  schema "lobbies" do
    field :name, :string
    field :password, :string
    field :owner_id, Ecto.UUID
    field :serv_lock, :boolean

    has_many :players, Popura.Player

    belongs_to :black_deck,    Popura.Deck, on_replace: :delete
    belongs_to :white_deck,    Popura.Deck, on_replace: :delete
    belongs_to :black_discard, Popura.Deck, on_replace: :delete
    belongs_to :white_discard, Popura.Deck, on_replace: :delete

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
    left_join: bc in assoc(l, :black_deck),
    left_join: bd in assoc(l, :black_discard),
    left_join: wc in assoc(l, :white_deck),
    left_join: wd in assoc(l, :white_discard),
    preload: [black_deck: bc, black_discard: bd],
    preload: [white_deck: wc, white_discard: wd]
  end

  def count_players(query) do
    from l in query,
    join: p in assoc(l, :players),
    select: count(p.id)
  end
end
