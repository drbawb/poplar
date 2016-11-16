defmodule Popura.LobbyView do
  use Popura.Web, :view
  import Ecto.Query

  alias Popura.Repo
  alias Popura.Deck
  alias Popura.Lobby

  def list_decks() do
    Repo.all(Deck)
    |> Enum.map(fn el -> {el.name, el.id} end)
  end

  def count_black(cards) do
    Enum.filter(cards, fn el -> el.tag == Lobby.black_deck end)
    |> Enum.count
  end

  def count_white(cards) do
    Enum.filter(cards, fn el -> el.tag == Lobby.white_deck end)
    |> Enum.count
  end

  def count_black_discard(cards) do
    Enum.filter(cards, fn el -> el.tag == Lobby.black_discard end)
    |> Enum.count
  end
  
  def count_white_discard(cards) do
    Enum.filter(cards, fn el -> el.tag == Lobby.white_discard end)
    |> Enum.count
  end
end
