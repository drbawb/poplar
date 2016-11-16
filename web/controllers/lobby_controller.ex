defmodule Popura.LobbyController do
  require Logger

  use Popura.Web, :controller

  import Ecto.Changeset, only: [put_change: 3, put_assoc: 3]
  alias Ecto.Multi
  alias Popura.Card
  alias Popura.Deck
  alias Popura.DeckCard
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
    black_discard = Deck.changeset(%Deck{is_generated: true, name: "sys", cards: []}, %{}) |> Repo.insert!
    white_discard = Deck.changeset(%Deck{is_generated: true, name: "sys", cards: []}, %{}) |> Repo.insert!
    black_cards   = Deck.changeset(%Deck{is_generated: true, name: "sys", cards: black_cards}, %{}) |> Repo.insert!
    white_cards   = Deck.changeset(%Deck{is_generated: true, name: "sys", cards: white_cards}, %{}) |> Repo.insert!

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

      render(conn, "show.html", lobby: lobby, token: token, is_admin: (user_id == lobby.owner_id))
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

  # TODO(hime): non-standard actions for controlling associated LobbyServ

  @doc """
  Starts a LobbyServ in the global namespace if possible.
  """
  def start(conn, %{"id" => id} = _params) do
    lobby = Repo.get!(Lobby, id)
    ident = "lobby:#{lobby.id}"

    # start a process to monitor this lobby
    Popura.LobbyServ.start_link [name: {:global, ident}]

    # instruct it to start handling events from WS transports
    case GenServer.call({:global, ident}, {:start, lobby.id}) do
      :ok ->
        conn
        |> put_flash(:info, "Server started up")
        |> redirect(to: lobby_path(conn, :show, lobby))       

      {:error, msg} ->
        conn
        |> put_flash(:error, "Could not start server: #{inspect msg}")
        |> redirect(to: lobby_path(conn, :show, lobby))
    end
  end

  def stop(conn, %{"id" => id} = _params) do
    lobby = Repo.get!(Lobby, id)
    ident = "lobby:#{lobby.id}"

    status = GenServer.stop({:global, ident})

    status = lobby
    |> Lobby.changeset
    |> put_change(:serv_lock, false)
    |> Repo.update

    case status do
      {:ok, _lobby} ->
        conn
        |> put_flash(:info, "Server stopped ok and unlocked")
        |> redirect(to: lobby_path(conn, :show, lobby))

      {:error, msg} ->
        conn
        |> put_flash(:error, "Server could not stop because: #{inspect msg}")
        |> redirect(to: lobby_path(conn, :show, lobby))
    end
  end

  # destroys current deck(s) and rebuilds them
  def reset(conn, %{"id" => id} = _params) do
    lobby = Repo.one(Lobby.with_decks(from l in Lobby, where: l.id == ^id))
    Logger.warn "loaded lobby :: #{inspect lobby}"

    # move discards back to normal decks
    # TODO(hime): doesn't perma-discard winning submissions
    black_discards = from dc in DeckCard, where: dc.deck_id == ^lobby.black_discard_id
    white_discards = from dc in DeckCard, where: dc.deck_id == ^lobby.white_discard_id
    Repo.update_all(black_discards, set: [deck_id: lobby.black_deck_id])
    Repo.update_all(white_discards, set: [deck_id: lobby.white_deck_id])

    conn |> redirect(to: lobby_path(conn, :show, lobby))
  end
end
