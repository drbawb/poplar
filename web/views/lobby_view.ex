defmodule Popura.LobbyView do
  require Logger

  use Popura.Web, :view
  import Ecto.Query

  alias Popura.Repo
  alias Popura.Deck
  alias Popura.Lobby

  def list_decks() do
    Repo.all(Deck)
    |> Enum.map(fn el -> {el.name, el.id} end)
  end

  def count_black(lobby) do
    _count_cards(lobby, Lobby.black_deck)
  end

  def count_white(lobby) do
    _count_cards(lobby, Lobby.white_deck)
  end

  def count_black_discard(lobby) do
    _count_cards(lobby, Lobby.black_discard)
  end
  
  def count_white_discard(lobby) do
    _count_cards(lobby, Lobby.white_discard)
  end

  defp _count_cards(lobby, tag) do
    Logger.warn inspect(lobby)
    query = from(
      l in Lobby, 
      join: c in assoc(l, :cards),
      where: l.id == ^lobby and c.tag == ^tag,
      select: count(c.id))

    Repo.one(query) 
  end
end
