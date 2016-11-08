defmodule Popura.LobbyView do
  use Popura.Web, :view

  alias Popura.Repo
  alias Popura.Deck

  def list_decks() do
    Repo.all(Deck)
    |> Enum.map(fn el -> {el.name, el.id} end)
  end
end
