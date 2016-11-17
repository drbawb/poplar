defmodule Popura.Player do
  use Popura.Web, :model
  require Logger

  schema "players" do
    field :name, :string
    field :user_id, Ecto.UUID

    belongs_to :lobby, Popura.Lobby
    has_many   :cards, Popura.CardPile, on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :user_id])
    |> validate_required([:name, :user_id, :lobby_id])
    |> unique_constraint(:name, name: "players_lobby_id_name_index")
  end
end
