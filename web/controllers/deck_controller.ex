defmodule Popura.DeckController do
  use Popura.Web, :controller

  alias Popura.Deck

  def index(conn, _params) do
    # load all decks not part of a lobby
    base_decks = Repo.all(from d in Deck)
    
    conn
    |> assign(:decks, base_decks)
    |> render("index.html")
  end

  def show(conn, %{"id" => deck_id} = _params) do
    deck = Repo.get!(Deck, deck_id)

    conn
    |> assign(:deck, deck)
    |> render("show.html")
  end

  def new(conn, _params) do
    changeset = Deck.changeset(%Deck{})

    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end
end
