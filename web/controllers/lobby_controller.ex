defmodule Popura.LobbyController do
  use Popura.Web, :controller

  import Ecto.Changeset, only: [put_change: 3]
  alias Popura.Card
  alias Popura.Deck
  alias Popura.Lobby
  alias Popura.Player

  def index(conn, _params) do
    lobbies = Repo.all(Lobby)
    render(conn, "index.html", lobbies: lobbies)
  end

  def new(conn, _params) do
    changeset = Lobby.changeset(%Lobby{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"lobby" => lobby_params}) do
    
    # load and sort cards
    {deck_id,lobby_params} = Map.pop(lobby_params, "deck_id")
    all_cards   = Repo.get!(Deck, deck_id) |> Repo.preload([:cards])
    black_cards = all_cards.cards |> Enum.filter(fn el -> el.slots >= 1 end)
    white_cards = all_cards.cards |> Enum.filter(fn el -> el.slots == 0 end)

    # build some decks
    black_discard = Deck.changeset(%Deck{name: "sys", cards: []}, %{}) |> Repo.insert!
    white_discard = Deck.changeset(%Deck{name: "sys", cards: []}, %{}) |> Repo.insert!
    black_cards   = Deck.changeset(%Deck{name: "sys", cards: black_cards}, %{}) |> Repo.insert!
    white_cards   = Deck.changeset(%Deck{name: "sys", cards: white_cards}, %{}) |> Repo.insert!

    # build the lobby
    changeset = Lobby.changeset(%Lobby{
      black_deck: black_cards,
      white_deck: white_cards,
      black_discard: black_discard,
      white_discard: white_discard}, lobby_params)

    case Repo.insert(changeset) do
      {:ok, _lobby} ->
        conn
        |> put_flash(:info, "Lobby created successfully.")
        |> redirect(to: lobby_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    user_id = get_session(conn, :auth_id)
    player  = Repo.one(from p in Player, where: p.user_id == ^user_id and p.lobby_id == ^id)

    if player == nil do
      conn
      |> put_flash(:info, "You are not a member of that lobby.")
      |> redirect(to: lobby_path(conn, :index))
    else
      token = Phoenix.Token.sign(Popura.Endpoint, "user", user_id)
      lobby = Repo.get!(Lobby, id) 
              |> Repo.preload([:players])
              |> Repo.preload([:black_deck, :white_deck, :black_discard, :white_discard])
              |> Repo.preload([black_deck: :cards, white_deck: :cards])
              |> Repo.preload([black_discard: :cards, white_discard: :cards])


      render(conn, "show.html", lobby: lobby, token: token)
    end
  end

  def edit(conn, %{"id" => id}) do
    lobby = Repo.get!(Lobby, id)
    changeset = Lobby.changeset(lobby)
    render(conn, "edit.html", lobby: lobby, changeset: changeset)
  end

  def update(conn, %{"id" => id, "lobby" => lobby_params}) do
    lobby = Repo.get!(Lobby, id)
    changeset = Lobby.changeset(lobby, lobby_params)

    case Repo.update(changeset) do
      {:ok, lobby} ->
        conn
        |> put_flash(:info, "Lobby updated successfully.")
        |> redirect(to: lobby_path(conn, :show, lobby))
      {:error, changeset} ->
        render(conn, "edit.html", lobby: lobby, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    lobby = Repo.get!(Lobby, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(lobby)

    conn
    |> put_flash(:info, "Lobby deleted successfully.")
    |> redirect(to: lobby_path(conn, :index))
  end
end
